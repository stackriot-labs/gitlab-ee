require 'spec_helper'

describe Projects::UpdateMirrorService do
  let(:project) { create(:project, :mirror, import_url: Project::UNKNOWN_IMPORT_URL) }

  describe "#execute" do
    it "fetches the upstream repository" do
      expect(project).to receive(:fetch_mirror)

      described_class.new(project, project.owner).execute
    end

    it "succeeds" do
      stub_fetch_mirror(project)

      result = described_class.new(project, project.owner).execute

      expect(result[:status]).to eq(:success)
    end

    describe "updating tags" do
      it "creates new tags" do
        stub_fetch_mirror(project)

        described_class.new(project, project.owner).execute

        expect(project.repository.tag_names).to include('new-tag')
      end

      it "only invokes GitTagPushService for tags pointing to commits" do
        stub_fetch_mirror(project)

        expect(GitTagPushService).to receive(:new).
          with(project, project.owner, hash_including(ref: 'refs/tags/new-tag')).and_return(double(execute: true))

        described_class.new(project, project.owner).execute
      end
    end

    describe "updating branches" do
      it "creates new branches" do
        stub_fetch_mirror(project)

        described_class.new(project, project.owner).execute

        expect(project.repository.branch_names).to include('new-branch')
      end

      it "updates existing branches" do
        stub_fetch_mirror(project)

        described_class.new(project, project.owner).execute

        expect(project.repository.find_branch('existing-branch').dereferenced_target)
          .to eq(project.repository.find_branch('master').dereferenced_target)
      end

      it "doesn't update diverged branches" do
        stub_fetch_mirror(project)

        described_class.new(project, project.owner).execute

        expect(project.repository.find_branch('markdown').dereferenced_target)
          .not_to eq(project.repository.find_branch('master').dereferenced_target)
      end
    end

    describe "when the mirror user doesn't have access" do
      it "fails" do
        stub_fetch_mirror(project)

        result = described_class.new(project, build_stubbed(:user)).execute

        expect(result[:status]).to eq(:error)
      end
    end

    describe "when no user is present" do
      it "fails" do
        result = described_class.new(project, nil).execute

        expect(result[:status]).to eq(:error)
      end
    end

    describe "when is no mirror" do
      let(:project) { build_stubbed(:project) }

      it "fails" do
        expect(project.mirror?).to eq(false)

        result = described_class.new(project, build_stubbed(:user)).execute

        expect(result[:status]).to eq(:error)
      end
    end
  end

  def stub_fetch_mirror(project, repository: project.repository)
    allow(project).to receive(:fetch_mirror) { fetch_mirror(repository) }
  end

  def fetch_mirror(repository)
    rugged = repository.rugged
    masterrev = repository.find_branch('master').dereferenced_target.id

    parentrev = repository.commit(masterrev).parent_id
    rugged.references.create('refs/heads/existing-branch', parentrev)

    repository.expire_branches_cache
    repository.branches

    # New branch
    rugged.references.create('refs/remotes/upstream/new-branch', masterrev)

    # Updated existing branch
    rugged.references.create('refs/remotes/upstream/existing-branch', masterrev)

    # Diverged branch
    rugged.references.create('refs/remotes/upstream/markdown', masterrev)

    # New tag
    rugged.references.create('refs/tags/new-tag', masterrev)

    # New tag that point to a blob
    rugged.references.create('refs/tags/new-tag-on-blob', 'c74175afd117781cbc983664339a0f599b5bb34e')
  end
end
