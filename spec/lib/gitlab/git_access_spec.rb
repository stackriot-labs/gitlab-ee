require 'spec_helper'

describe Gitlab::GitAccess, lib: true do
  let(:access) { Gitlab::GitAccess.new(actor, project, 'web', authentication_abilities: authentication_abilities) }
  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let(:actor) { user }
  let(:git_annex_changes) do
    ["6f6d7e7ed97bb5f0054f2b1df789b39ca89b6ff9 570e7b2abdd848b95f2f578043fc23bd6f6fd24d refs/heads/synced/git-annex",
     "6f6d7e7ed97bb5f0054f2b1df789b39ca89b6ff9 570e7b2abdd848b95f2f578043fc23bd6f6fd24d refs/heads/synced/named-branch"]
  end
  let(:git_annex_master_changes) { "6f6d7e7ed97bb5f0054f2b1df789b39ca89b6ff9 570e7b2abdd848b95f2f578043fc23bd6f6fd24d refs/heads/master" }
  let(:authentication_abilities) do
    [
      :read_project,
      :download_code,
      :push_code
    ]
  end

  describe '#check with single protocols allowed' do
    def disable_protocol(protocol)
      settings = ::ApplicationSetting.create_from_defaults
      settings.update_attribute(:enabled_git_access_protocol, protocol)
    end

    context 'ssh disabled' do
      before do
        disable_protocol('ssh')
        @acc = Gitlab::GitAccess.new(actor, project, 'ssh', authentication_abilities: authentication_abilities)
      end

      it 'blocks ssh git push' do
        expect(@acc.check('git-receive-pack', '_any').allowed?).to be_falsey
      end

      it 'blocks ssh git pull' do
        expect(@acc.check('git-upload-pack', '_any').allowed?).to be_falsey
      end
    end

    context 'http disabled' do
      before do
        disable_protocol('http')
        @acc = Gitlab::GitAccess.new(actor, project, 'http', authentication_abilities: authentication_abilities)
      end

      it 'blocks http push' do
        expect(@acc.check('git-receive-pack', '_any').allowed?).to be_falsey
      end

      it 'blocks http git pull' do
        expect(@acc.check('git-upload-pack', '_any').allowed?).to be_falsey
      end
    end
  end

  describe 'download_access_check' do
    subject { access.check('git-upload-pack', '_any') }

    describe 'master permissions' do
      before { project.team << [user, :master] }

      context 'pull code' do
        it { expect(subject.allowed?).to be_truthy }
      end
    end

    describe 'guest permissions' do
      before { project.team << [user, :guest] }

      context 'pull code' do
        it { expect(subject.allowed?).to be_falsey }
        it { expect(subject.message).to match(/You are not allowed to download code/) }
      end
    end

    describe 'blocked user' do
      before do
        project.team << [user, :master]
        user.block
      end

      context 'pull code' do
        it { expect(subject.allowed?).to be_falsey }
        it { expect(subject.message).to match(/Your account has been blocked/) }
      end
    end

    describe 'without acccess to project' do
      context 'pull code' do
        it { expect(subject.allowed?).to be_falsey }
      end

      context 'when project is public' do
        let(:public_project) { create(:project, :public) }
        let(:guest_access) { Gitlab::GitAccess.new(nil, public_project, 'web', authentication_abilities: []) }
        subject { guest_access.check('git-upload-pack', '_any') }

        context 'when repository is enabled' do
          it 'give access to download code' do
            public_project.project_feature.update_attribute(:repository_access_level, ProjectFeature::ENABLED)

            expect(subject.allowed?).to be_truthy
          end
        end

        context 'when repository is disabled' do
          it 'does not give access to download code' do
            public_project.project_feature.update_attribute(:repository_access_level, ProjectFeature::DISABLED)

            expect(subject.allowed?).to be_falsey
            expect(subject.message).to match(/You are not allowed to download code/)
          end
        end
      end
    end

    describe 'deploy key permissions' do
      let(:key) { create(:deploy_key) }
      let(:actor) { key }

      context 'pull code' do
        context 'when project is authorized' do
          before { key.projects << project }

          it { expect(subject).to be_allowed }
        end

        context 'when unauthorized' do
          context 'from public project' do
            let(:project) { create(:project, :public) }

            it { expect(subject).to be_allowed }
          end

          context 'from internal project' do
            let(:project) { create(:project, :internal) }

            it { expect(subject).not_to be_allowed }
          end

          context 'from private project' do
            let(:project) { create(:project, :internal) }

            it { expect(subject).not_to be_allowed }
          end
        end
      end
    end

    describe 'geo node key permissions' do
      let(:key) { build(:geo_node_key) }
      let(:actor) { key }

      context 'pull code' do
        subject { access.download_access_check }

        it { expect { subject }.not_to raise_error }
      end
    end

    describe 'build authentication_abilities permissions' do
      let(:authentication_abilities) { build_authentication_abilities }

      describe 'owner' do
        let(:project) { create(:project, namespace: user.namespace) }

        context 'pull code' do
          it { expect { subject }.not_to raise_error }
        end
      end

      describe 'reporter user' do
        before { project.team << [user, :reporter] }

        context 'pull code' do
          it { expect { subject }.not_to raise_error }
        end
      end

      describe 'admin user' do
        let(:user) { create(:admin) }

        context 'when member of the project' do
          before { project.team << [user, :reporter] }

          context 'pull code' do
            it { expect { subject }.not_to raise_error }
          end
        end

        context 'when is not member of the project' do
          context 'pull code' do
            it { expect { subject }.not_to raise_error }
          end
        end
      end
    end
  end

  describe 'push_access_check' do
    before { merge_into_protected_branch }
    let(:unprotected_branch) { FFaker::Internet.user_name }

    let(:changes) do
      { push_new_branch: "#{Gitlab::Git::BLANK_SHA} 570e7b2ab refs/heads/wow",
        push_master: '6f6d7e7ed 570e7b2ab refs/heads/master',
        push_protected_branch: '6f6d7e7ed 570e7b2ab refs/heads/feature',
        push_remove_protected_branch: "570e7b2ab #{Gitlab::Git::BLANK_SHA} "\
                                      'refs/heads/feature',
        push_tag: '6f6d7e7ed 570e7b2ab refs/tags/v1.0.0',
        push_new_tag: "#{Gitlab::Git::BLANK_SHA} 570e7b2ab refs/tags/v7.8.9",
        push_all: ['6f6d7e7ed 570e7b2ab refs/heads/master', '6f6d7e7ed 570e7b2ab refs/heads/feature'],
        merge_into_protected_branch: "0b4bc9a #{merge_into_protected_branch} refs/heads/feature" }
    end

    def stub_git_hooks
      # Running the `pre-receive` hook is expensive, and not necessary for this test.
      allow_any_instance_of(GitHooksService).to receive(:execute).and_yield
    end

    def merge_into_protected_branch
      @protected_branch_merge_commit ||= begin
                                           stub_git_hooks
                                           project.repository.add_branch(user, unprotected_branch, 'feature')
                                           target_branch = project.repository.lookup('feature')
                                           source_branch = project.repository.commit_file(user, FFaker::InternetSE.login_user_name, FFaker::HipsterIpsum.paragraph, FFaker::HipsterIpsum.sentence, unprotected_branch, false)
                                           rugged = project.repository.rugged
                                           author = { email: "email@example.com", time: Time.now, name: "Example Git User" }

                                           merge_index = rugged.merge_commits(target_branch, source_branch)
                                           Rugged::Commit.create(rugged, author: author, committer: author, message: "commit message", parents: [target_branch, source_branch], tree: merge_index.write_tree(rugged))
                                         end
    end

    # Run permission checks for a user
    def self.run_permission_checks(permissions_matrix)
      permissions_matrix.keys.each do |role|
        describe "#{role} access" do
          before do
            if role == :admin
              user.update_attribute(:admin, true)
            else
              project.team << [user, role]
            end

            permissions_matrix[role].each do |action, allowed|
              context action do
                subject { access.push_access_check(changes[action]) }

                it do
                  if allowed
                    expect { subject }.not_to raise_error
                  else
                    expect { subject }.to raise_error(Gitlab::GitAccess::UnauthorizedError)
                  end
                end
              end
            end
          end
        end
      end
    end

    # Run permission checks for a group
    def self.run_group_permission_checks(permissions_matrix)
      permissions_matrix.keys.each do |role|
        describe "#{role} access" do
          before do
            project.project_group_links.create(
              group: group, group_access: Gitlab::Access.sym_options[role]
            )
          end

          permissions_matrix[role].each do |action, allowed|
            context action do
              subject { access.push_access_check(changes[action]) }

              it do
                if allowed
                  expect { subject }.not_to raise_error
                else
                  expect { subject }.to raise_error(Gitlab::GitAccess::UnauthorizedError)
                end
              end
            end
          end
        end
      end
    end

    permissions_matrix = {
      admin: {
        push_new_branch: true,
        push_master: true,
        push_protected_branch: true,
        push_remove_protected_branch: false,
        push_tag: true,
        push_new_tag: true,
        push_all: true,
        merge_into_protected_branch: true
      },

      master: {
        push_new_branch: true,
        push_master: true,
        push_protected_branch: true,
        push_remove_protected_branch: false,
        push_tag: true,
        push_new_tag: true,
        push_all: true,
        merge_into_protected_branch: true
      },

      developer: {
        push_new_branch: true,
        push_master: true,
        push_protected_branch: false,
        push_remove_protected_branch: false,
        push_tag: false,
        push_new_tag: true,
        push_all: false,
        merge_into_protected_branch: false
      },

      reporter: {
        push_new_branch: false,
        push_master: false,
        push_protected_branch: false,
        push_remove_protected_branch: false,
        push_tag: false,
        push_new_tag: false,
        push_all: false,
        merge_into_protected_branch: false
      },

      guest: {
        push_new_branch: false,
        push_master: false,
        push_protected_branch: false,
        push_remove_protected_branch: false,
        push_tag: false,
        push_new_tag: false,
        push_all: false,
        merge_into_protected_branch: false
      }
    }

    [['feature', 'exact'], ['feat*', 'wildcard']].each do |protected_branch_name, protected_branch_type|
      context do
        before { create(:protected_branch, :remove_default_access_levels, :masters_can_push, name: protected_branch_name, project: project) }

        run_permission_checks(permissions_matrix)
      end

      context "when developers are allowed to push into the #{protected_branch_type} protected branch" do
        before { create(:protected_branch, :remove_default_access_levels, :masters_can_push, :developers_can_push, name: protected_branch_name, project: project) }

        run_permission_checks(permissions_matrix.deep_merge(developer: { push_protected_branch: true, push_all: true, merge_into_protected_branch: true }))
      end

      context "developers are allowed to merge into the #{protected_branch_type} protected branch" do
        before { create(:protected_branch, :remove_default_access_levels, :masters_can_push, :developers_can_merge, name: protected_branch_name, project: project) }

        context "when a merge request exists for the given source/target branch" do
          context "when the merge request is in progress" do
            before do
              create(:merge_request, source_project: project, source_branch: unprotected_branch, target_branch: 'feature',
                                     state: 'locked', in_progress_merge_commit_sha: merge_into_protected_branch)
            end

            run_permission_checks(permissions_matrix.deep_merge(developer: { merge_into_protected_branch: true }))
          end

          context "when the merge request is not in progress" do
            before do
              create(:merge_request, source_project: project, source_branch: unprotected_branch, target_branch: 'feature', in_progress_merge_commit_sha: nil)
            end

            run_permission_checks(permissions_matrix.deep_merge(developer: { merge_into_protected_branch: false }))
          end

          context "when a merge request does not exist for the given source/target branch" do
            run_permission_checks(permissions_matrix.deep_merge(developer: { merge_into_protected_branch: false }))
          end
        end
      end

      context "when developers are allowed to push and merge into the #{protected_branch_type} protected branch" do
        before { create(:protected_branch, :remove_default_access_levels, :masters_can_push, :developers_can_merge, :developers_can_push, name: protected_branch_name, project: project) }

        run_permission_checks(permissions_matrix.deep_merge(developer: { push_protected_branch: true, push_all: true, merge_into_protected_branch: true }))
      end

      context "user-specific access control" do
        context "when a specific user is allowed to push into the #{protected_branch_type} protected branch" do
          let(:user) { create(:user) }

          before do
            create(:protected_branch, :remove_default_access_levels, authorize_user_to_push: user, name: protected_branch_name, project: project)
          end

          run_permission_checks(permissions_matrix.deep_merge(developer: { push_protected_branch: true, push_all: true, merge_into_protected_branch: true },
                                                              guest: { push_protected_branch: false, merge_into_protected_branch: false },
                                                              reporter: { push_protected_branch: false, merge_into_protected_branch: false }))
        end

        context "when a specific user is allowed to merge into the #{protected_branch_type} protected branch" do
          let(:user) { create(:user) }

          before do
            create(:merge_request, source_project: project, source_branch: unprotected_branch, target_branch: 'feature', state: 'locked', in_progress_merge_commit_sha: merge_into_protected_branch)
            create(:protected_branch, :remove_default_access_levels, authorize_user_to_merge: user, name: protected_branch_name, project: project)
          end

          run_permission_checks(permissions_matrix.deep_merge(admin: { push_protected_branch: false, push_all: false, merge_into_protected_branch: true },
                                                              master: { push_protected_branch: false, push_all: false, merge_into_protected_branch: true },
                                                              developer: { push_protected_branch: false, push_all: false, merge_into_protected_branch: true },
                                                              guest: { push_protected_branch: false, merge_into_protected_branch: false },
                                                              reporter: { push_protected_branch: false, merge_into_protected_branch: false }))
        end

        context "when a specific user is allowed to push & merge into the #{protected_branch_type} protected branch" do
          let(:user) { create(:user) }

          before do
            create(:merge_request, source_project: project, source_branch: unprotected_branch, target_branch: 'feature', state: 'locked', in_progress_merge_commit_sha: merge_into_protected_branch)
            create(:protected_branch, :remove_default_access_levels, authorize_user_to_push: user, authorize_user_to_merge: user, name: protected_branch_name, project: project)
          end

          run_permission_checks(permissions_matrix.deep_merge(developer: { push_protected_branch: true, push_all: true, merge_into_protected_branch: true },
                                                              guest: { push_protected_branch: false, merge_into_protected_branch: false },
                                                              reporter: { push_protected_branch: false, merge_into_protected_branch: false }))
        end
      end

      context "group-specific access control" do
        context "when a specific group is allowed to push into the #{protected_branch_type} protected branch" do
          let(:user) { create(:user) }
          let(:group) { create(:group) }

          before do
            group.add_master(user)
            create(:protected_branch, :remove_default_access_levels, authorize_group_to_push: group, name: protected_branch_name, project: project)
          end

          permissions = permissions_matrix.except(:admin).deep_merge(developer: { push_protected_branch: true, push_all: true, merge_into_protected_branch: true },
                                                                     guest: { push_protected_branch: false, merge_into_protected_branch: false },
                                                                     reporter: { push_protected_branch: false, merge_into_protected_branch: false })

          run_group_permission_checks(permissions)
        end

        context "when a specific group is allowed to merge into the #{protected_branch_type} protected branch" do
          let(:user) { create(:user) }
          let(:group) { create(:group) }

          before do
            group.add_master(user)
            create(:merge_request, source_project: project, source_branch: unprotected_branch, target_branch: 'feature', state: 'locked', in_progress_merge_commit_sha: merge_into_protected_branch)
            create(:protected_branch, :remove_default_access_levels, authorize_group_to_merge: group, name: protected_branch_name, project: project)
          end

          permissions = permissions_matrix.except(:admin).deep_merge(master: { push_protected_branch: false, push_all: false, merge_into_protected_branch: true },
                                                                     developer: { push_protected_branch: false, push_all: false, merge_into_protected_branch: true },
                                                                     guest: { push_protected_branch: false, merge_into_protected_branch: false },
                                                                     reporter: { push_protected_branch: false, merge_into_protected_branch: false })

          run_group_permission_checks(permissions)
        end

        context "when a specific group is allowed to push & merge into the #{protected_branch_type} protected branch" do
          let(:user) { create(:user) }
          let(:group) { create(:group) }

          before do
            group.add_master(user)
            create(:merge_request, source_project: project, source_branch: unprotected_branch, target_branch: 'feature', state: 'locked', in_progress_merge_commit_sha: merge_into_protected_branch)
            create(:protected_branch, :remove_default_access_levels, authorize_group_to_push: group, authorize_group_to_merge: group, name: protected_branch_name, project: project)
          end

          permissions = permissions_matrix.except(:admin).deep_merge(developer: { push_protected_branch: true, push_all: true, merge_into_protected_branch: true },
                                                                     guest: { push_protected_branch: false, merge_into_protected_branch: false },
                                                                     reporter: { push_protected_branch: false, merge_into_protected_branch: false })

          run_group_permission_checks(permissions)
        end
      end

      context "when no one is allowed to push to the #{protected_branch_name} protected branch" do
        before { create(:protected_branch, :remove_default_access_levels, :no_one_can_push, name: protected_branch_name, project: project) }

        run_permission_checks(permissions_matrix.deep_merge(developer: { push_protected_branch: false, push_all: false, merge_into_protected_branch: false },
                                                            master: { push_protected_branch: false, push_all: false, merge_into_protected_branch: false },
                                                            admin: { push_protected_branch: false, push_all: false, merge_into_protected_branch: false }))
      end
    end

    context "when license blocks changes" do
      before do
        create(:protected_branch, name: 'feature', project: project)
        allow(License).to receive(:block_changes?).and_return(true)
      end

      # All permissions are `false`
      permissions_matrix = Hash.new(Hash.new(false))

      run_permission_checks(permissions_matrix)
    end

    context "when in a secondary gitlab geo node" do
      before do
        create(:protected_branch, name: 'feature', project: project)
        allow(Gitlab::Geo).to receive(:enabled?) { true }
        allow(Gitlab::Geo).to receive(:secondary?) { true }
      end

      # All permissions are `false`
      permissions_matrix = Hash.new(Hash.new(false))

      run_permission_checks(permissions_matrix)
    end

    context "when using git annex" do
      before do
        project.team << [user, :master]

        allow_any_instance_of(Repository).to receive(:new_commits).and_return(
          project.repository.commits_between('6f6d7e7ed97bb5f0054f2b1df789b39ca89b6ff9', '570e7b2abdd848b95f2f578043fc23bd6f6fd24d')
        )
      end

      describe 'and gitlab geo is enabled in a secondary node' do
        before do
          allow(Gitlab.config.gitlab_shell).to receive(:git_annex_enabled).and_return(true)
          allow(Gitlab::Geo).to receive(:enabled?) { true }
          allow(Gitlab::Geo).to receive(:secondary?) { true }
        end

        it { expect { access.push_access_check(git_annex_changes) }.to raise_error(described_class::UnauthorizedError) }
      end

      describe 'and git hooks unset' do
        describe 'git annex enabled' do
          before { allow(Gitlab.config.gitlab_shell).to receive(:git_annex_enabled).and_return(true) }

          it { expect { access.push_access_check(git_annex_changes) }.not_to raise_error }
        end

        describe 'git annex disabled' do
          before { allow(Gitlab.config.gitlab_shell).to receive(:git_annex_enabled).and_return(false) }

          it { expect { access.push_access_check(git_annex_changes) }.not_to raise_error }
        end
      end

      describe 'and push rules set' do
        before { project.create_push_rule }

        describe 'check commit author email' do
          before do
            project.push_rule.update(author_email_regex: "@only.com")
          end

          describe 'git annex enabled' do
            before { allow(Gitlab.config.gitlab_shell).to receive(:git_annex_enabled).and_return(true) }

            it { expect { access.push_access_check(git_annex_changes) }.not_to raise_error }
          end

          describe 'git annex enabled, push to master branch' do
            before do
              allow(Gitlab.config.gitlab_shell).to receive(:git_annex_enabled).and_return(true)
              allow_any_instance_of(Commit).to receive(:safe_message) { 'git-annex in me@host:~/repo' }
            end

            it { expect { access.push_access_check(git_annex_master_changes) }.not_to raise_error }
          end

          describe 'git annex disabled' do
            before do
              allow(Gitlab.config.gitlab_shell).to receive(:git_annex_enabled).and_return(false)
            end

            it { expect { access.push_access_check(git_annex_changes) }.to raise_error(described_class::UnauthorizedError) }
          end
        end

        describe 'check max file size' do
          before do
            allow_any_instance_of(Gitlab::Git::Blob).to receive(:size).and_return(5.megabytes.to_i)
            project.push_rule.update(max_file_size: 2)
          end

          describe 'git annex enabled' do
            before { allow(Gitlab.config.gitlab_shell).to receive(:git_annex_enabled).and_return(true) }

            it { expect(access.check('git-annex-shell', git_annex_changes).allowed?).to be_truthy }
            it { expect { access.push_access_check(git_annex_changes) }.not_to raise_error }
          end

          describe 'git annex disabled' do
            before do
              allow(Gitlab.config.gitlab_shell).to receive(:git_annex_enabled).and_return(false)
            end

            it { expect(access.check('git-annex-shell', git_annex_changes).allowed?).to be_falsey }
            it { expect { access.push_access_check(git_annex_changes) }.to raise_error(described_class::UnauthorizedError) }
          end
        end
      end
    end

    describe "push_rule_check" do
      before do
        project.team << [user, :developer]

        allow_any_instance_of(Repository).to receive(:new_commits).and_return(
          project.repository.commits_between('6f6d7e7ed97bb5f0054f2b1df789b39ca89b6ff9', '570e7b2abdd848b95f2f578043fc23bd6f6fd24d')
        )
      end

      describe "author email check" do
        it 'returns true' do
          expect { access.push_access_check('6f6d7e7ed97bb5f0054f2b1df789b39ca89b6ff9 570e7b2abdd848b95f2f578043fc23bd6f6fd24d refs/heads/master') }.not_to raise_error
        end

        it 'returns false' do
          project.create_push_rule
          project.push_rule.update(commit_message_regex: "@only.com")

          expect { access.push_access_check('6f6d7e7ed97bb5f0054f2b1df789b39ca89b6ff9 570e7b2abdd848b95f2f578043fc23bd6f6fd24d refs/heads/master') }.to raise_error(described_class::UnauthorizedError)
        end

        it 'returns true for tags' do
          project.create_push_rule
          project.push_rule.update(commit_message_regex: "@only.com")

          expect { access.push_access_check('6f6d7e7ed97bb5f0054f2b1df789b39ca89b6ff9 570e7b2abdd848b95f2f578043fc23bd6f6fd24d refs/tags/v1') }.not_to raise_error
        end

        it 'allows githook for new branch with an old bad commit' do
          bad_commit = double("Commit", safe_message: 'Some change').as_null_object
          ref_object = double(name: 'heads/master')
          allow(bad_commit).to receive(:refs).and_return([ref_object])
          allow_any_instance_of(Repository).to receive(:commits_between).and_return([bad_commit])

          project.create_push_rule
          project.push_rule.update(commit_message_regex: "Change some files")

          # push to new branch, so use a blank old rev and new ref
          expect { access.push_access_check("#{Gitlab::Git::BLANK_SHA} 570e7b2abdd848b95f2f578043fc23bd6f6fd24d refs/heads/new-branch") }.not_to raise_error
        end

        it 'allows githook for any change with an old bad commit' do
          bad_commit = double("Commit", safe_message: 'Some change').as_null_object
          ref_object = double(name: 'heads/master')
          allow(bad_commit).to receive(:refs).and_return([ref_object])
          allow_any_instance_of(Repository).to receive(:commits_between).and_return([bad_commit])

          project.create_push_rule
          project.push_rule.update(commit_message_regex: "Change some files")

          # push to new branch, so use a blank old rev and new ref
          expect { access.push_access_check('6f6d7e7ed97bb5f0054f2b1df789b39ca89b6ff9 570e7b2abdd848b95f2f578043fc23bd6f6fd24d refs/heads/master') }.not_to raise_error
        end

        it 'does not allow any change from Web UI with bad commit' do
          bad_commit = double("Commit", safe_message: 'Some change').as_null_object
          # We use tmp ref a a temporary for Web UI commiting
          ref_object = double(name: 'refs/tmp')
          allow(bad_commit).to receive(:refs).and_return([ref_object])
          allow_any_instance_of(Repository).to receive(:commits_between).and_return([bad_commit])
          allow_any_instance_of(Repository).to receive(:new_commits).and_return([bad_commit])

          project.create_push_rule
          project.push_rule.update(commit_message_regex: "Change some files")

          # push to new branch, so use a blank old rev and new ref
          expect { access.push_access_check('6f6d7e7ed97bb5f0054f2b1df789b39ca89b6ff9 570e7b2abdd848b95f2f578043fc23bd6f6fd24d refs/heads/master') }.to raise_error(described_class::UnauthorizedError)
        end
      end

      describe "member_check" do
        before do
          project.create_push_rule
          project.push_rule.update(member_check: true)
        end

        it 'returns false for non-member user' do
          expect { access.push_access_check('6f6d7e7ed97bb5f0054f2b1df789b39ca89b6ff9 570e7b2abdd848b95f2f578043fc23bd6f6fd24d refs/heads/master') }.to raise_error(described_class::UnauthorizedError)
        end

        it 'returns true if committer is a gitlab member' do
          create(:user, email: 'dmitriy.zaporozhets@gmail.com')

          expect { access.push_access_check('6f6d7e7ed97bb5f0054f2b1df789b39ca89b6ff9 570e7b2abdd848b95f2f578043fc23bd6f6fd24d refs/heads/master') }.not_to raise_error
        end
      end

      describe "file names check" do
        before do
          allow_any_instance_of(Repository).to receive(:new_commits).and_return(
            project.repository.commits_between('913c66a37b4a45b9769037c55c2d238bd0942d2e', '33f3729a45c02fc67d00adb1b8bca394b0e761d9')
          )
        end

        it 'returns false when filename is prohibited' do
          project.create_push_rule
          project.push_rule.update(file_name_regex: "jpg$")

          expect { access.push_access_check('913c66a37b4a45b9769037c55c2d238bd0942d2e 33f3729a45c02fc67d00adb1b8bca394b0e761d9 refs/heads/master') }.to raise_error(described_class::UnauthorizedError)
        end

        it 'returns true if file name is allowed' do
          project.create_push_rule
          project.push_rule.update(file_name_regex: "exe$")

          expect { access.push_access_check('913c66a37b4a45b9769037c55c2d238bd0942d2e 33f3729a45c02fc67d00adb1b8bca394b0e761d9 refs/heads/master') }.not_to raise_error
        end
      end

      describe "max file size check" do
        before do
          allow_any_instance_of(Gitlab::Git::Blob).to receive(:size).and_return(1.5.megabytes.to_i)
        end

        it "returns false when size is too large" do
          project.create_push_rule
          project.push_rule.update(max_file_size: 1)

          expect { access.push_access_check('cfe32cf61b73a0d5e9f13e774abde7ff789b1660 913c66a37b4a45b9769037c55c2d238bd0942d2e refs/heads/master') }.to raise_error(described_class::UnauthorizedError)
        end

        it "returns true when size is allowed" do
          project.create_push_rule
          project.push_rule.update(max_file_size: 2)

          expect { access.push_access_check('cfe32cf61b73a0d5e9f13e774abde7ff789b1660 913c66a37b4a45b9769037c55c2d238bd0942d2e refs/heads/master') }.not_to raise_error
        end

        it "returns true when size is nil" do
          allow_any_instance_of(Gitlab::Git::Blob).to receive(:size).and_return(nil)
          project.create_push_rule
          project.push_rule.update(max_file_size: 2)

          expect { access.push_access_check('cfe32cf61b73a0d5e9f13e774abde7ff789b1660 913c66a37b4a45b9769037c55c2d238bd0942d2e refs/heads/master') }.not_to raise_error
        end
      end

      describe 'repository size restrictions' do
        before do
          project.update_attribute(:repository_size_limit, 50)
        end

        it 'returns false when blob is too big' do
          allow_any_instance_of(Gitlab::Git::Blob).to receive(:size).and_return(100.megabytes.to_i)

          expect { access.push_access_check('cfe32cf61b73a0d5e9f13e774abde7ff789b1660 913c66a37b4a45b9769037c55c2d238bd0942d2e refs/heads/master') }.to raise_error(described_class::UnauthorizedError)
        end

        it 'returns true when blob is just right' do
          allow_any_instance_of(Gitlab::Git::Blob).to receive(:size).and_return(2.megabytes.to_i)

          expect { access.push_access_check('cfe32cf61b73a0d5e9f13e774abde7ff789b1660 913c66a37b4a45b9769037c55c2d238bd0942d2e refs/heads/master') }.not_to raise_error
        end
      end
    end
  end

  shared_examples 'can not push code' do
    subject { access.check('git-receive-pack', '_any') }

    context 'when project is authorized' do
      before { authorize }

      it { expect(subject).not_to be_allowed }
    end

    context 'when unauthorized' do
      context 'to public project' do
        let(:project) { create(:project, :public) }

        it { expect(subject).not_to be_allowed }
      end

      context 'to internal project' do
        let(:project) { create(:project, :internal) }

        it { expect(subject).not_to be_allowed }
      end

      context 'to private project' do
        let(:project) { create(:project) }

        it { expect(subject).not_to be_allowed }
      end
    end
  end

  describe 'build authentication abilities' do
    let(:authentication_abilities) { build_authentication_abilities }

    it_behaves_like 'can not push code' do
      def authorize
        project.team << [user, :reporter]
      end
    end
  end

  context 'when the repository is read only' do
    it 'denies push access' do
      project = create(:project, :read_only_repository)
      project.team << [user, :master]

      check = access.check('git-receive-pack', '_any')

      expect(check).not_to be_allowed
    end
  end

  describe 'deploy key permissions' do
    let(:key) { create(:deploy_key) }
    let(:actor) { key }

    it_behaves_like 'can not push code' do
      def authorize
        key.projects << project
      end
    end
  end

  private

  def build_authentication_abilities
    [
      :read_project,
      :build_download_code
    ]
  end

  def full_authentication_abilities
    [
      :read_project,
      :download_code,
      :push_code
    ]
  end
end
