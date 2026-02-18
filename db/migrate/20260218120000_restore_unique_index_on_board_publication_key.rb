class RestoreUniqueIndexOnBoardPublicationKey < ActiveRecord::Migration[8.2]
  def change
    add_index :board_publications, :key, unique: true
    add_index :board_publications, :account_id
    remove_index :board_publications, [:account_id, :key]
  end
end
