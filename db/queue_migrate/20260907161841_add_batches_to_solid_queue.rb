class AddBatchesToSolidQueue < ActiveRecord::Migration[7.1]
  def change
    # Fresh installs create all of this with the base schema, so skip
    # anything that already exists
    add_column :solid_queue_jobs, :batch_id, :bigint, if_not_exists: true
    add_index :solid_queue_jobs, :batch_id, if_not_exists: true

    create_table :solid_queue_batches, if_not_exists: true do |t|
      t.string :active_job_batch_id
      t.string :description
      t.text :on_finish
      t.text :on_success
      t.text :on_failure
      t.text :metadata
      t.integer :total_jobs, default: 0, null: false
      t.integer :completed_jobs, default: 0, null: false
      t.integer :failed_jobs, default: 0, null: false
      t.datetime :enqueued_at
      t.datetime :finished_at
      t.datetime :failed_at
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false

      t.index :active_job_batch_id, unique: true
      t.index :finished_at
    end

    create_table :solid_queue_batch_executions, if_not_exists: true do |t|
      t.bigint :job_id, null: false
      t.bigint :batch_id, null: false
      t.datetime :created_at, null: false

      t.index :job_id, unique: true
      t.index :batch_id
      t.foreign_key :solid_queue_batches, column: :batch_id, on_delete: :cascade
      t.foreign_key :solid_queue_jobs, column: :job_id, on_delete: :cascade
    end
  end
end
