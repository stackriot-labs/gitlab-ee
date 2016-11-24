require 'spec_helper'

describe ElasticCommitIndexerWorker do
  let(:project) { create(:project) }

  subject { described_class.new }

  describe '#perform' do
    before do
      stub_application_setting(elasticsearch_indexing: true)
    end

    it 'runs indexer' do
      expect_any_instance_of(Gitlab::Elastic::Indexer).to receive(:run)
      subject.perform(project.id, '0000', '0000')
    end

    it 'does not run indexer when project is empty' do
      empty_project = create :empty_project

      expect_any_instance_of(Gitlab::Elastic::Indexer).not_to receive(:run)

      subject.perform(empty_project.id, '0000', '0000')
    end

    it 'returns true if repository has unborn head' do
      project = create :project
      repository = double('repository')
      expect(repository).to receive(:exists?).and_return(false)
      expect_any_instance_of(Project).to receive(:repository).and_return(repository)

      expect(subject.perform(project.id)).to be_truthy
    end

    it 'returns true if ES disabled' do
      stub_application_setting(elasticsearch_indexing: false)

      expect_any_instance_of(Gitlab::Elastic::Indexer).not_to receive(:run)

      expect(subject.perform(1)).to be_truthy
    end
  end
end
