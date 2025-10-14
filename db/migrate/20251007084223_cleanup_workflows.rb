class CleanupWorkflows < ActiveRecord::Migration[8.1]
  def change
    remove_foreign_key :cards, :workflow_stages
    remove_foreign_key :collections, :workflows
    remove_foreign_key :workflow_stages, :workflows

    drop_table :filters_stages

    remove_column :cards, :stage_id
    remove_column :collections, :workflow_id

    drop_table :workflow_stages
    drop_table :workflows
  end
end
