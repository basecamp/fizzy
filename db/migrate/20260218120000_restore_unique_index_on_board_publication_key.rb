class RestoreUniqueIndexOnBoardPublicationKey < ActiveRecord::Migration[8.2]
  def change
    remove_index :board_publications, [:account_id, :key]
    add_index :board_publications, :key, unique: true
    add_index :board_publications, :account_id
  end
end
