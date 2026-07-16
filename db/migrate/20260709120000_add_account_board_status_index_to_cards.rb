class AddAccountBoardStatusIndexToCards < ActiveRecord::Migration[8.2]
  def change
    add_index :cards, [ :account_id, :board_id, :status ]
  end
end
