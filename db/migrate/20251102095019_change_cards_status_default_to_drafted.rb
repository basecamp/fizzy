class ChangeCardsStatusDefaultToDrafted < ActiveRecord::Migration[8.2]
  def change
    change_column_default :cards, :status, from: "creating", to: "drafted"
  end
end
