class ProjectGroupLink < ActiveRecord::Base
  include Expirable

  GUEST     = 10
  REPORTER  = 20
  DEVELOPER = 30
  MASTER    = 40

  belongs_to :project
  belongs_to :group

  validates :project_id, presence: true
  validates :group, presence: true
  validates :group_id, uniqueness: { scope: [:project_id], message: "already shared with this group" }
  validates :group_access, presence: true
  validates :group_access, inclusion: { in: Gitlab::Access.values }, presence: true
  validate :different_group

  before_destroy :delete_branch_protection
  after_create :refresh_group_members_authorized_projects
  after_destroy :refresh_group_members_authorized_projects

  def self.access_options
    Gitlab::Access.options
  end

  def self.default_access
    DEVELOPER
  end

  def human_access
    self.class.access_options.key(self.group_access)
  end

  private

  def different_group
    if self.group && self.project && self.project.group == self.group
      errors.add(:base, "Project cannot be shared with the project it is in.")
    end
  end

  def delete_branch_protection
    if group.present? && project.present?
      project.protected_branches.merge_access_by_group(group).destroy_all
      project.protected_branches.push_access_by_group(group).destroy_all
    end
  end

  def refresh_group_members_authorized_projects
    group.refresh_members_authorized_projects
  end
end
