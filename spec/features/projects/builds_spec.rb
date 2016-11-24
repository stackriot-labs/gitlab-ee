require 'spec_helper'
require 'tempfile'

describe "Builds" do
  let(:artifacts_file) { fixture_file_upload(Rails.root + 'spec/fixtures/banana_sample.gif', 'image/gif') }

  before do
    login_as(:user)
    @commit = FactoryGirl.create :ci_pipeline
    @build = FactoryGirl.create :ci_build, :trace, pipeline: @commit
    @build2 = FactoryGirl.create :ci_build
    @project = @commit.project
    @project.team << [@user, :developer]
  end

  describe "GET /:project/builds" do
    context "Pending scope" do
      before do
        visit namespace_project_builds_path(@project.namespace, @project, scope: :pending)
      end

      it "shows Pending tab builds" do
        expect(page).to have_link 'Cancel running'
        expect(page).to have_selector('.nav-links li.active', text: 'Pending')
        expect(page).to have_content @build.short_sha
        expect(page).to have_content @build.ref
        expect(page).to have_content @build.name
      end
    end

    context "Running scope" do
      before do
        @build.run!
        visit namespace_project_builds_path(@project.namespace, @project, scope: :running)
      end

      it "shows Running tab builds" do
        expect(page).to have_selector('.nav-links li.active', text: 'Running')
        expect(page).to have_link 'Cancel running'
        expect(page).to have_content @build.short_sha
        expect(page).to have_content @build.ref
        expect(page).to have_content @build.name
      end
    end

    context "Finished scope" do
      before do
        @build.run!
        visit namespace_project_builds_path(@project.namespace, @project, scope: :finished)
      end

      it "shows Finished tab builds" do
        expect(page).to have_selector('.nav-links li.active', text: 'Finished')
        expect(page).to have_content 'No builds to show'
        expect(page).to have_link 'Cancel running'
      end
    end

    context "All builds" do
      before do
        @project.builds.running_or_pending.each(&:success)
        visit namespace_project_builds_path(@project.namespace, @project)
      end

      it "shows All tab builds" do
        expect(page).to have_selector('.nav-links li.active', text: 'All')
        expect(page).to have_content @build.short_sha
        expect(page).to have_content @build.ref
        expect(page).to have_content @build.name
        expect(page).not_to have_link 'Cancel running'
      end
    end
  end

  describe "POST /:project/builds/:id/cancel_all" do
    before do
      @build.run!
      visit namespace_project_builds_path(@project.namespace, @project)
      click_link "Cancel running"
    end

    it 'shows all necessary content' do
      expect(page).to have_selector('.nav-links li.active', text: 'All')
      expect(page).to have_content 'canceled'
      expect(page).to have_content @build.short_sha
      expect(page).to have_content @build.ref
      expect(page).to have_content @build.name
      expect(page).not_to have_link 'Cancel running'
    end
  end

  describe "GET /:project/builds/:id" do
    context "Build from project" do
      before do
        visit namespace_project_build_path(@project.namespace, @project, @build)
      end

      it 'shows commit`s data' do
        expect(page.status_code).to eq(200)
        expect(page).to have_content @commit.sha[0..7]
        expect(page).to have_content @commit.git_commit_message
        expect(page).to have_content @commit.git_author_name
      end
    end

    context "Build from other project" do
      before do
        visit namespace_project_build_path(@project.namespace, @project, @build2)
      end

      it { expect(page.status_code).to eq(404) }
    end

    context "Download artifacts" do
      before do
        @build.update_attributes(artifacts_file: artifacts_file)
        visit namespace_project_build_path(@project.namespace, @project, @build)
      end

      it 'has button to download artifacts' do
        expect(page).to have_content 'Download'
      end
    end

    context 'Artifacts expire date' do
      before do
        @build.update_attributes(artifacts_file: artifacts_file, artifacts_expire_at: expire_at)
        visit namespace_project_build_path(@project.namespace, @project, @build)
      end

      context 'no expire date defined' do
        let(:expire_at) { nil }

        it 'does not have the Keep button' do
          expect(page).not_to have_content 'Keep'
        end
      end

      context 'when expire date is defined' do
        let(:expire_at) { Time.now + 7.days }

        it 'keeps artifacts when Keep button is clicked' do
          expect(page).to have_content 'The artifacts will be removed'
          click_link 'Keep'

          expect(page).not_to have_link 'Keep'
          expect(page).not_to have_content 'The artifacts will be removed'
        end
      end

      context 'when artifacts expired' do
        let(:expire_at) { Time.now - 7.days }

        it 'does not have the Keep button' do
          expect(page).to have_content 'The artifacts were removed'
          expect(page).not_to have_link 'Keep'
        end
      end
    end

    context 'Build raw trace' do
      before do
        @build.run!
        visit namespace_project_build_path(@project.namespace, @project, @build)
      end

      it do
        expect(page).to have_link 'Raw'
      end
    end

    describe 'Variables' do
      before do
        @trigger_request = create :ci_trigger_request_with_variables
        @build = create :ci_build, pipeline: @commit, trigger_request: @trigger_request
        visit namespace_project_build_path(@project.namespace, @project, @build)
      end

      it 'shows variable key and value after click', js: true do
        expect(page).to have_css('.reveal-variables')
        expect(page).not_to have_css('.js-build-variable')
        expect(page).not_to have_css('.js-build-value')

        click_button 'Reveal Variables'

        expect(page).not_to have_css('.reveal-variables')
        expect(page).to have_selector('.js-build-variable', text: 'TRIGGER_KEY_1')
        expect(page).to have_selector('.js-build-value', text: 'TRIGGER_VALUE_1')
      end
    end
  end

  describe "POST /:project/builds/:id/cancel" do
    context "Build from project" do
      before do
        @build.run!
        visit namespace_project_build_path(@project.namespace, @project, @build)
        click_link "Cancel"
      end

      it 'loads the page and shows all needed controls' do
        expect(page.status_code).to eq(200)
        expect(page).to have_content 'canceled'
        expect(page).to have_content 'Retry'
      end
    end

    context "Build from other project" do
      before do
        @build.run!
        visit namespace_project_build_path(@project.namespace, @project, @build)
        page.driver.post(cancel_namespace_project_build_path(@project.namespace, @project, @build2))
      end

      it { expect(page.status_code).to eq(404) }
    end
  end

  describe "POST /:project/builds/:id/retry" do
    context "Build from project" do
      before do
        @build.run!
        visit namespace_project_build_path(@project.namespace, @project, @build)
        click_link 'Cancel'
        page.within('.build-header') do
          click_link 'Retry build'
        end
      end

      it 'shows the right status and buttons' do
        expect(page).to have_http_status(200)
        expect(page).to have_content 'pending'
        page.within('aside.right-sidebar') do
          expect(page).to have_content 'Cancel'
        end
      end
    end

    context "Build from other project" do
      before do
        @build.run!
        visit namespace_project_build_path(@project.namespace, @project, @build)
        click_link 'Cancel'
        page.driver.post(retry_namespace_project_build_path(@project.namespace, @project, @build2))
      end

      it { expect(page).to have_http_status(404) }
    end

    context "Build that current user is not allowed to retry" do
      before do
        @build.run!
        @build.cancel!
        @project.update(visibility_level: Gitlab::VisibilityLevel::PUBLIC)

        logout_direct
        login_with(create(:user))
        visit namespace_project_build_path(@project.namespace, @project, @build)
      end

      it 'does not show the Retry button' do
        page.within('aside.right-sidebar') do
          expect(page).not_to have_content 'Retry'
        end
      end
    end
  end

  describe "GET /:project/builds/:id/download" do
    before do
      @build.update_attributes(artifacts_file: artifacts_file)
      visit namespace_project_build_path(@project.namespace, @project, @build)
      click_link 'Download'
    end

    context "Build from other project" do
      before do
        @build2.update_attributes(artifacts_file: artifacts_file)
        visit download_namespace_project_build_artifacts_path(@project.namespace, @project, @build2)
      end

      it { expect(page.status_code).to eq(404) }
    end
  end

  describe 'GET /:project/builds/:id/raw' do
    context 'access source' do
      context 'build from project' do
        before do
          Capybara.current_session.driver.header('X-Sendfile-Type', 'X-Sendfile')
          @build.run!
          visit namespace_project_build_path(@project.namespace, @project, @build)
          page.within('.js-build-sidebar') { click_link 'Raw' }
        end

        it 'sends the right headers' do
          expect(page.status_code).to eq(200)
          expect(page.response_headers['Content-Type']).to eq('text/plain; charset=utf-8')
          expect(page.response_headers['X-Sendfile']).to eq(@build.path_to_trace)
        end
      end

      context 'build from other project' do
        before do
          Capybara.current_session.driver.header('X-Sendfile-Type', 'X-Sendfile')
          @build2.run!
          visit raw_namespace_project_build_path(@project.namespace, @project, @build2)
        end

        it 'sends the right headers' do
          expect(page.status_code).to eq(404)
        end
      end
    end

    context 'storage form' do
      let(:existing_file) { Tempfile.new('existing-trace-file').path }
      let(:non_existing_file) do
        file = Tempfile.new('non-existing-trace-file')
        path = file.path
        file.unlink
        path
      end

      context 'when build has trace in file' do
        before do
          Capybara.current_session.driver.header('X-Sendfile-Type', 'X-Sendfile')
          @build.run!
          visit namespace_project_build_path(@project.namespace, @project, @build)

          allow_any_instance_of(Project).to receive(:ci_id).and_return(nil)
          allow_any_instance_of(Ci::Build).to receive(:path_to_trace).and_return(existing_file)
          allow_any_instance_of(Ci::Build).to receive(:old_path_to_trace).and_return(non_existing_file)

          page.within('.js-build-sidebar') { click_link 'Raw' }
        end

        it 'sends the right headers' do
          expect(page.status_code).to eq(200)
          expect(page.response_headers['Content-Type']).to eq('text/plain; charset=utf-8')
          expect(page.response_headers['X-Sendfile']).to eq(existing_file)
        end
      end

      context 'when build has trace in old file' do
        before do
          Capybara.current_session.driver.header('X-Sendfile-Type', 'X-Sendfile')
          @build.run!
          visit namespace_project_build_path(@project.namespace, @project, @build)

          allow_any_instance_of(Project).to receive(:ci_id).and_return(999)
          allow_any_instance_of(Ci::Build).to receive(:path_to_trace).and_return(non_existing_file)
          allow_any_instance_of(Ci::Build).to receive(:old_path_to_trace).and_return(existing_file)

          page.within('.js-build-sidebar') { click_link 'Raw' }
        end

        it 'sends the right headers' do
          expect(page.status_code).to eq(200)
          expect(page.response_headers['Content-Type']).to eq('text/plain; charset=utf-8')
          expect(page.response_headers['X-Sendfile']).to eq(existing_file)
        end
      end

      context 'when build has trace in DB' do
        before do
          Capybara.current_session.driver.header('X-Sendfile-Type', 'X-Sendfile')
          @build.run!
          visit namespace_project_build_path(@project.namespace, @project, @build)

          allow_any_instance_of(Project).to receive(:ci_id).and_return(nil)
          allow_any_instance_of(Ci::Build).to receive(:path_to_trace).and_return(non_existing_file)
          allow_any_instance_of(Ci::Build).to receive(:old_path_to_trace).and_return(non_existing_file)

          page.within('.js-build-sidebar') { click_link 'Raw' }
        end

        it 'sends the right headers' do
          expect(page.status_code).to eq(404)
        end
      end
    end
  end

  describe "GET /:project/builds/:id/trace.json" do
    context "Build from project" do
      before do
        visit trace_namespace_project_build_path(@project.namespace, @project, @build, format: :json)
      end

      it { expect(page.status_code).to eq(200) }
    end

    context "Build from other project" do
      before do
        visit trace_namespace_project_build_path(@project.namespace, @project, @build2, format: :json)
      end

      it { expect(page.status_code).to eq(404) }
    end
  end

  describe "GET /:project/builds/:id/status" do
    context "Build from project" do
      before do
        visit status_namespace_project_build_path(@project.namespace, @project, @build)
      end

      it { expect(page.status_code).to eq(200) }
    end

    context "Build from other project" do
      before do
        visit status_namespace_project_build_path(@project.namespace, @project, @build2)
      end

      it { expect(page.status_code).to eq(404) }
    end
  end
end
