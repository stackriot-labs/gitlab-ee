module Ci
  class Pipeline < ActiveRecord::Base
    extend Ci::Model
    include HasStatus
    include Importable
    include AfterCommitQueue

    self.table_name = 'ci_commits'

    belongs_to :project, foreign_key: :gl_project_id
    belongs_to :user

    has_many :statuses, class_name: 'CommitStatus', foreign_key: :commit_id
    has_many :builds, foreign_key: :commit_id
    has_many :trigger_requests, dependent: :destroy, foreign_key: :commit_id

    validates_presence_of :sha, unless: :importing?
    validates_presence_of :ref, unless: :importing?
    validates_presence_of :status, unless: :importing?
    validate :valid_commit_sha, unless: :importing?

    after_create :keep_around_commits, unless: :importing?

    delegate :stages, to: :statuses

    state_machine :status, initial: :created do
      event :enqueue do
        transition created: :pending
        transition [:success, :failed, :canceled, :skipped] => :running
      end

      event :run do
        transition any - [:running] => :running
      end

      event :skip do
        transition any - [:skipped] => :skipped
      end

      event :drop do
        transition any - [:failed] => :failed
      end

      event :succeed do
        transition any - [:success] => :success
      end

      event :cancel do
        transition any - [:canceled] => :canceled
      end

      # IMPORTANT
      # Do not add any operations to this state_machine
      # Create a separate worker for each new operation

      before_transition [:created, :pending] => :running do |pipeline|
        pipeline.started_at = Time.now
      end

      before_transition any => [:success, :failed, :canceled] do |pipeline|
        pipeline.finished_at = Time.now
        pipeline.update_duration
      end

      after_transition [:created, :pending] => :running do |pipeline|
        pipeline.run_after_commit { PipelineMetricsWorker.perform_async(id) }
      end

      after_transition any => [:success] do |pipeline|
        pipeline.run_after_commit { PipelineMetricsWorker.perform_async(id) }
      end

      after_transition [:created, :pending, :running] => :success do |pipeline|
        pipeline.run_after_commit { PipelineSuccessWorker.perform_async(id) }
      end

      after_transition do |pipeline, transition|
        next if transition.loopback?

        pipeline.run_after_commit do
          PipelineHooksWorker.perform_async(id)
        end
      end

      after_transition any => [:success, :failed] do |pipeline|
        pipeline.run_after_commit do
          PipelineNotificationWorker.perform_async(pipeline.id)
        end
      end
    end

    # ref can't be HEAD or SHA, can only be branch/tag name
    def self.latest_successful_for(ref)
      where(ref: ref).order(id: :desc).success.first
    end

    def self.truncate_sha(sha)
      sha[0...8]
    end

    def self.stages
      # We use pluck here due to problems with MySQL which doesn't allow LIMIT/OFFSET in queries
      CommitStatus.where(pipeline: pluck(:id)).stages
    end

    def self.total_duration
      where.not(duration: nil).sum(:duration)
    end

    def stages_with_latest_statuses
      statuses.latest.includes(project: :namespace).order(:stage_idx).group_by(&:stage)
    end

    def project_id
      project.id
    end

    # For now the only user who participates is the user who triggered
    def participants(_current_user = nil)
      Array(user)
    end

    def valid_commit_sha
      if self.sha == Gitlab::Git::BLANK_SHA
        self.errors.add(:sha, " cant be 00000000 (branch removal)")
      end
    end

    def git_author_name
      commit.try(:author_name)
    end

    def git_author_email
      commit.try(:author_email)
    end

    def git_commit_message
      commit.try(:message)
    end

    def git_commit_title
      commit.try(:title)
    end

    def short_sha
      Ci::Pipeline.truncate_sha(sha)
    end

    def commit
      @commit ||= project.commit(sha)
    rescue
      nil
    end

    def branch?
      !tag?
    end

    def manual_actions
      builds.latest.manual_actions
    end

    def retryable?
      builds.latest.any? do |build|
        (build.failed? || build.canceled?) && build.retryable?
      end
    end

    def cancelable?
      builds.running_or_pending.any?
    end

    def cancel_running
      builds.running_or_pending.each(&:cancel)
    end

    def retry_failed(user)
      builds.latest.failed.select(&:retryable?).each do |build|
        Ci::Build.retry(build, user)
      end
    end

    def mark_as_processable_after_stage(stage_idx)
      builds.skipped.where('stage_idx > ?', stage_idx).find_each(&:process)
    end

    def latest?
      return false unless ref
      commit = project.commit(ref)
      return false unless commit
      commit.sha == sha
    end

    def triggered?
      trigger_requests.any?
    end

    def retried
      @retried ||= (statuses.order(id: :desc) - statuses.latest)
    end

    def coverage
      coverage_array = statuses.latest.map(&:coverage).compact
      if coverage_array.size >= 1
        '%.2f' % (coverage_array.reduce(:+) / coverage_array.size)
      end
    end

    def config_builds_attributes
      return [] unless config_processor

      config_processor.
        builds_for_ref(ref, tag?, trigger_requests.first).
        sort_by { |build| build[:stage_idx] }
    end

    def has_warnings?
      builds.latest.failed_but_allowed.any?
    end

    def config_processor
      return nil unless ci_yaml_file
      return @config_processor if defined?(@config_processor)

      @config_processor ||= begin
        Ci::GitlabCiYamlProcessor.new(ci_yaml_file, project.path_with_namespace)
      rescue Ci::GitlabCiYamlProcessor::ValidationError, Psych::SyntaxError => e
        self.yaml_errors = e.message
        nil
      rescue
        self.yaml_errors = 'Undefined error'
        nil
      end
    end

    def ci_yaml_file
      return @ci_yaml_file if defined?(@ci_yaml_file)

      @ci_yaml_file ||= begin
        blob = project.repository.blob_at(sha, '.gitlab-ci.yml')
        blob.load_all_data!(project.repository)
        blob.data
      rescue
        nil
      end
    end

    def environments
      builds.where.not(environment: nil).success.pluck(:environment).uniq
    end

    # Manually set the notes for a Ci::Pipeline
    # There is no ActiveRecord relation between Ci::Pipeline and notes
    # as they are related to a commit sha. This method helps importing
    # them using the +Gitlab::ImportExport::RelationFactory+ class.
    def notes=(notes)
      notes.each do |note|
        note[:id] = nil
        note[:commit_id] = sha
        note[:noteable_id] = self['id']
        note.save!
      end
    end

    def notes
      Note.for_commit_id(sha)
    end

    def process!
      Ci::ProcessPipelineService.new(project, user).execute(self)
    end

    def update_status
      Gitlab::OptimisticLocking.retry_lock(self) do
        case latest_builds_status
        when 'pending' then enqueue
        when 'running' then run
        when 'success' then succeed
        when 'failed' then drop
        when 'canceled' then cancel
        when 'skipped' then skip
        end
      end
    end

    def predefined_variables
      [
        { key: 'CI_PIPELINE_ID', value: id.to_s, public: true }
      ]
    end

    def queued_duration
      return unless started_at

      seconds = (started_at - created_at).to_i
      seconds unless seconds.zero?
    end

    def update_duration
      return unless started_at

      self.duration = Gitlab::Ci::PipelineDuration.from_pipeline(self)
    end

    def execute_hooks
      data = pipeline_data
      project.execute_hooks(data, :pipeline_hooks)
      project.execute_services(data, :pipeline_hooks)
    end

    # Merge requests for which the current pipeline is running against
    # the merge request's latest commit.
    def merge_requests
      @merge_requests ||= project.merge_requests
        .where(source_branch: self.ref)
        .select { |merge_request| merge_request.pipeline.try(:id) == self.id }
    end

    private

    def pipeline_data
      Gitlab::DataBuilder::Pipeline.build(self)
    end

    def latest_builds_status
      return 'failed' unless yaml_errors.blank?

      statuses.latest.status || 'skipped'
    end

    def keep_around_commits
      return unless project

      project.repository.keep_around(self.sha)
      project.repository.keep_around(self.before_sha)
    end
  end
end
