class CreateBoardArchivals < ActiveRecord::Migration[8.2]
  def change
    create_table :board_archivals, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.uuid :board_id, null: false
      t.uuid :user_id

      t.timestamps

      t.index :account_id
      t.index :board_id, unique: true
      t.index :user_id
    end
  end
end
