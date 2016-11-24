# See http://doc.gitlab.com/ce/development/migration_style_guide.html
# for more information on how to write migrations for GitLab.

class AddPipelineIdToMergeRequestMetrics < ActiveRecord::Migration
  include Gitlab::Database::MigrationHelpers

  disable_ddl_transaction!

  # Set this constant to true if this migration requires downtime.
  DOWNTIME = true

  # When a migration requires downtime you **must** uncomment the following
  # constant and define a short and easy to understand explanation as to why the
  # migration requires downtime.
  DOWNTIME_REASON = 'Adding a foreign key'

  # When using the methods "add_concurrent_index" or "add_column_with_default"
  # you must disable the use of transactions as these methods can not run in an
  # existing transaction. When using "add_concurrent_index" make sure that this
  # method is the _only_ method called in the migration, any other changes
  # should go in a separate migration. This ensures that upon failure _only_ the
  # index creation fails and can be retried or reverted easily.
  #
  # To disable transactions uncomment the following line and remove these
  # comments:
  # disable_ddl_transaction!

  def change
    add_column :merge_request_metrics, :pipeline_id, :integer
    add_concurrent_index :merge_request_metrics, :pipeline_id
    add_foreign_key :merge_request_metrics, :ci_commits, column: :pipeline_id, on_delete: :cascade
  end
end
