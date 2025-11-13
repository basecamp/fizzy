class CreateSearchRecordShards < ActiveRecord::Migration[8.2]
  SHARD_COUNT = 16

  def up
    # Create 16 sharded search_records tables
    SHARD_COUNT.times do |shard_id|
      create_table "search_records_#{shard_id}", id: :uuid do |t|
        t.uuid :account_id, null: false
        t.string :searchable_type, null: false
        t.uuid :searchable_id, null: false
        t.uuid :card_id, null: false
        t.uuid :board_id, null: false
        t.string :title
        t.text :content
        t.datetime :created_at, null: false

        t.index [:searchable_type, :searchable_id], unique: true
        t.index :account_id
        t.index [:content, :title], type: :fulltext
      end
    end

    # Drop old search_index tables
    SHARD_COUNT.times do |shard_id|
      drop_table "search_index_#{shard_id}", if_exists: true
    end
  end

  def down
    SHARD_COUNT.times do |shard_id|
      drop_table "search_records_#{shard_id}"
    end
  end
end
