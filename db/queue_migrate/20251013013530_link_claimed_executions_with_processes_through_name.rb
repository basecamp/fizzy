class LinkClaimedExecutionsWithProcessesThroughName < ActiveRecord::Migration[8.1]
  def up
    unless connection.column_exists?(:solid_queue_claimed_executions, :process_name)
      add_column :solid_queue_claimed_executions, :process_name, :string
      add_index :solid_queue_claimed_executions, :process_name
    end

    unless connection.index_exists?(:solid_queue_processes, :name)
      add_index :solid_queue_processes, :name, unique: true
    end

    if connection.index_exists?(:solid_queue_processes, [ :name, :supervisor_id ])
      remove_index :solid_queue_processes, [ :name, :supervisor_id ]
    end
  end

  def down
    if connection.column_exists?(:solid_queue_claimed_executions, :process_name)
      remove_column :solid_queue_claimed_executions, :process_name
    end

    if connection.index_exists?(:solid_queue_processes, :name)
      remove_index :solid_queue_processes, :name
    end

    unless connection.index_exists?(:solid_queue_processes, [ :name, :supervisor_id ])
      add_index :solid_queue_processes, [ :name, :supervisor_id ], unique: true
    end
  end
end
