class Environment < ActiveRecord::Base
  belongs_to :project, required: true, validate: true

  has_many :deployments

  before_validation :nullify_external_url
  before_save :set_environment_type

  validates :name,
            presence: true,
            uniqueness: { scope: :project_id },
            length: { within: 0..255 },
            format: { with: Gitlab::Regex.environment_name_regex,
                      message: Gitlab::Regex.environment_name_regex_message }

  validates :external_url,
            uniqueness: { scope: :project_id },
            length: { maximum: 255 },
            allow_nil: true,
            addressable_url: true

  delegate :stop_action, :manual_actions, to: :last_deployment, allow_nil: true

  scope :available, -> { with_state(:available) }
  scope :stopped, -> { with_state(:stopped) }

  state_machine :state, initial: :available do
    event :start do
      transition stopped: :available
    end

    event :stop do
      transition available: :stopped
    end

    state :available
    state :stopped
  end

  def recently_updated_on_branch?(ref)
    ref.to_s == last_deployment.try(:ref)
  end

  def last_deployment
    deployments.last
  end

  def nullify_external_url
    self.external_url = nil if self.external_url.blank?
  end

  def set_environment_type
    names = name.split('/')

    self.environment_type =
      if names.many?
        names.first
      else
        nil
      end
  end

  def includes_commit?(commit)
    return false unless last_deployment

    last_deployment.includes_commit?(commit)
  end

  def update_merge_request_metrics?
    self.name == "production"
  end

  def first_deployment_for(commit)
    ref = project.repository.ref_name_for_sha(ref_path, commit.sha)

    return nil unless ref

    deployment_iid = ref.split('/').last
    deployments.find_by(iid: deployment_iid)
  end

  def ref_path
    "refs/environments/#{Shellwords.shellescape(name)}"
  end

  def formatted_external_url
    return nil unless external_url

    external_url.gsub(/\A.*?:\/\//, '')
  end

  def stoppable?
    available? && stop_action.present?
  end

  def stop!(current_user)
    return unless stoppable?

    stop
    stop_action.play(current_user)
  end

  def actions_for(environment)
    return [] unless manual_actions

    manual_actions.select do |action|
      action.expanded_environment_name == environment
    end
  end
end
