class AddUserAndCardIndexToWatches < ActiveRecord::Migration[8.2]
  def change
    add_index :watches, %i[ user_id card_id ]
  end
end
