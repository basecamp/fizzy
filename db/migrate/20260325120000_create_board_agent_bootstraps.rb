class CreateBoardAgentBootstraps < ActiveRecord::Migration[8.2]
  def change
    create_table :board_agent_bootstraps, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.uuid :board_id, null: false
      t.uuid :creator_id, null: false
      t.uuid :claimed_by_identity_id
      t.string :token
      t.string :permission, null: false
      t.string :involvement, null: false
      t.datetime :expires_at, null: false
      t.datetime :claimed_at

      t.timestamps

      t.index :account_id
      t.index :board_id
      t.index :creator_id
      t.index :claimed_by_identity_id
      t.index :expires_at
      t.index :token, unique: true
    end
  end
end
