require 'spec_helper'
include ImportExport::CommonUtil

describe Gitlab::ImportExport::ProjectTreeRestorer, services: true do
  describe 'restore project tree' do
    let(:user) { create(:user) }
    let(:namespace) { create(:namespace, owner: user) }
    let(:shared) { Gitlab::ImportExport::Shared.new(relative_path: "", project_path: 'path') }
    let!(:project) { create(:empty_project, name: 'project', path: 'project', builds_access_level: ProjectFeature::DISABLED, issues_access_level: ProjectFeature::DISABLED) }
    let(:project_tree_restorer) { described_class.new(user: user, shared: shared, project: project) }
    let(:restored_project_json) { project_tree_restorer.restore }

    before do
      allow(shared).to receive(:export_path).and_return('spec/lib/gitlab/import_export/')
    end

    context 'JSON' do
      it 'restores models based on JSON' do
        expect(restored_project_json).to be true
      end

      it 'restore correct project features' do
        restored_project_json
        project = Project.find_by_path('project')

        expect(project.project_feature.issues_access_level).to eq(ProjectFeature::DISABLED)
        expect(project.project_feature.builds_access_level).to eq(ProjectFeature::DISABLED)
        expect(project.project_feature.snippets_access_level).to eq(ProjectFeature::ENABLED)
        expect(project.project_feature.wiki_access_level).to eq(ProjectFeature::ENABLED)
        expect(project.project_feature.merge_requests_access_level).to eq(ProjectFeature::ENABLED)
      end

      it 'has the same label associated to two issues' do
        restored_project_json

        expect(ProjectLabel.find_by_title('test2').issues.count).to eq(2)
      end

      it 'has milestones associated to two separate issues' do
        restored_project_json

        expect(Milestone.find_by_description('test milestone').issues.count).to eq(2)
      end

      it 'creates a valid pipeline note' do
        restored_project_json

        expect(Ci::Pipeline.first.notes).not_to be_empty
      end

      it 'restores pipelines with missing ref' do
        restored_project_json

        expect(Ci::Pipeline.where(ref: nil)).not_to be_empty
      end

      it 'restores the correct event with symbolised data' do
        restored_project_json

        expect(Event.where.not(data: nil).first.data[:ref]).not_to be_empty
      end

      it 'preserves updated_at on issues' do
        restored_project_json

        issue = Issue.where(description: 'Aliquam enim illo et possimus.').first

        expect(issue.reload.updated_at.to_s).to eq('2016-06-14 15:02:47 UTC')
      end

      it 'contains the merge access levels on a protected branch' do
        restored_project_json

        expect(ProtectedBranch.first.merge_access_levels).not_to be_empty
      end

      it 'contains the push access levels on a protected branch' do
        restored_project_json

        expect(ProtectedBranch.first.push_access_levels).not_to be_empty
      end

      context 'event at forth level of the tree' do
        let(:event) { Event.where(title: 'test levels').first }

        before do
          restored_project_json
        end

        it 'restores the event' do
          expect(event).not_to be_nil
        end

        it 'event belongs to note, belongs to merge request, belongs to a project' do
          expect(event.note.noteable.project).not_to be_nil
        end
      end

      it 'has the correct data for merge request st_diffs' do
        # makes sure we are renaming the custom method +utf8_st_diffs+ into +st_diffs+

        expect { restored_project_json }.to change(MergeRequestDiff.where.not(st_diffs: nil), :count).by(9)
      end

      it 'has labels associated to label links, associated to issues' do
        restored_project_json

        expect(Label.first.label_links.first.target).not_to be_nil
      end

      it 'has project labels' do
        restored_project_json

        expect(ProjectLabel.count).to eq(2)
      end

      it 'has no group labels' do
        restored_project_json

        expect(GroupLabel.count).to eq(0)
      end

      context 'with group' do
        let!(:project) do 
          create(:empty_project,
                                name: 'project',
                                path: 'project',
                                builds_access_level: ProjectFeature::DISABLED,
                                issues_access_level: ProjectFeature::DISABLED,
                                group: create(:group)) 
        end

        it 'has group labels' do
          restored_project_json

          expect(GroupLabel.count).to eq(1)
        end

        it 'has label priorities' do
          restored_project_json

          expect(GroupLabel.first.priorities).not_to be_empty
        end
      end

      it 'has a project feature' do
        restored_project_json

        expect(project.project_feature).not_to be_nil
      end

      it 'restores the correct service' do
        restored_project_json

        expect(CustomIssueTrackerService.first).not_to be_nil
      end

      context 'Merge requests' do
        before do
          restored_project_json
        end

        it 'always has the new project as a target' do
          expect(MergeRequest.find_by_title('MR1').target_project).to eq(project)
        end

        it 'has the same source project as originally if source/target are the same' do
          expect(MergeRequest.find_by_title('MR1').source_project).to eq(project)
        end

        it 'has the new project as target if source/target differ' do
          expect(MergeRequest.find_by_title('MR2').target_project).to eq(project)
        end

        it 'has no source if source/target differ' do
          expect(MergeRequest.find_by_title('MR2').source_project_id).to eq(-1)
        end
      end

      context 'project.json file access check' do
        it 'does not read a symlink' do
          Dir.mktmpdir do |tmpdir|
            setup_symlink(tmpdir, 'project.json')
            allow(shared).to receive(:export_path).and_call_original

            restored_project_json

            expect(shared.errors.first).not_to include('test')
          end
        end
      end
    end
  end
end
