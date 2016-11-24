require 'spec_helper'

describe Gitlab::ChatCommands::Command, service: true do
  let(:project) { create(:empty_project) }
  let(:user) { create(:user) }

  describe '#execute' do
    subject { described_class.new(project, user, params).execute }

    context 'when no command is available' do
      let(:params) { { text: 'issue show 1' } }
      let(:project) { create(:project, has_external_issue_tracker: true) }

      it 'displays 404 messages' do
        expect(subject[:response_type]).to be(:ephemeral)
        expect(subject[:text]).to start_with('404 not found')
      end
    end

    context 'when an unknown command is triggered' do
      let(:params) { { command: '/gitlab', text: "unknown command 123" } }

      it 'displays the help message' do
        expect(subject[:response_type]).to be(:ephemeral)
        expect(subject[:text]).to start_with('Available commands')
        expect(subject[:text]).to match('/gitlab issue show')
      end
    end

    context 'the user can not create an issue' do
      let(:params) { { text: "issue create my new issue" } }

      it 'rejects the actions' do
        expect(subject[:response_type]).to be(:ephemeral)
        expect(subject[:text]).to start_with('Whoops! That action is not allowed')
      end
    end

    context 'issue is successfully created' do
      let(:params) { { text: "issue create my new issue" } }

      before do
        project.team << [user, :master]
      end

      it 'presents the issue' do
        expect(subject[:text]).to match("my new issue")
      end

      it 'shows a link to the new issue' do
        expect(subject[:text]).to match(/\/issues\/\d+/)
      end
    end

    context 'when trying to do deployment' do
      let(:params) { { text: 'deploy staging to production' } }
      let!(:build) { create(:ci_build, project: project) }
      let!(:staging) { create(:environment, name: 'staging', project: project) }
      let!(:deployment) { create(:deployment, environment: staging, deployable: build) }
      let!(:manual) do
        create(:ci_build, :manual, project: project, pipeline: build.pipeline, name: 'first', environment: 'production')
      end

      context 'and user can not create deployment' do
        it 'returns action' do
          expect(subject[:response_type]).to be(:ephemeral)
          expect(subject[:text]).to start_with('Whoops! That action is not allowed')
        end
      end

      context 'and user does have deployment permission' do
        before do
          project.team << [user, :developer]
        end

        it 'returns action' do
          expect(subject[:text]).to include('Deployment from staging to production started')
          expect(subject[:response_type]).to be(:in_channel)
        end

        context 'when duplicate action exists' do
          let!(:manual2) do
            create(:ci_build, :manual, project: project, pipeline: build.pipeline, name: 'second', environment: 'production')
          end

          it 'returns error' do
            expect(subject[:response_type]).to be(:ephemeral)
            expect(subject[:text]).to include('Too many actions defined')
          end
        end
      end
    end
  end
end
