require 'spec_helper'

describe Gitlab::GitAccessWiki, lib: true do
  let(:access) { Gitlab::GitAccessWiki.new(user, project, 'web', authentication_abilities: authentication_abilities) }
  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let(:changes) { ['6f6d7e7ed 570e7b2ab refs/heads/master'] }
  let(:authentication_abilities) do
    [
      :read_project,
      :download_code,
      :push_code
    ]
  end

  describe '#push_access_check' do
    context 'when user can :create_wiki' do
      before do
        create(:protected_branch, name: 'master', project: project)
        project.team << [user, :developer]
      end

      subject { access.check('git-receive-pack', changes) }

      it { expect(subject.allowed?).to be_truthy }

      context 'when in a secondary gitlab geo node' do
        before do
          allow(Gitlab::Geo).to receive(:enabled?) { true }
          allow(Gitlab::Geo).to receive(:secondary?) { true }
        end

        it { expect(subject.allowed?).to be_falsey }
      end
    end
  end
end
