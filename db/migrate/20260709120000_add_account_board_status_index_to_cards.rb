class AddAccountBoardStatusIndexToCards < ActiveRecord::Migration[8.2]
  def change
    add_index :cards, [ :account_id, :board_id, :status ],
      name: "index_cards_on_account_id_and_board_id_and_status"
  end
end
