class RenameCollectionToBoard < ActiveRecord::Migration[8.2]
  def change
    # Rename the main collections table to boards
    rename_table :collections, :boards

    # Rename collection_publications to board_publications
    rename_table :collection_publications, :board_publications

    # Rename the join table
    rename_table :collections_filters, :boards_filters

    # Rename collection_id columns to board_id in all tables
    rename_column :accesses, :collection_id, :board_id
    rename_column :cards, :collection_id, :board_id
    rename_column :board_publications, :collection_id, :board_id
    rename_column :columns, :collection_id, :board_id
    rename_column :events, :collection_id, :board_id
    rename_column :webhooks, :collection_id, :board_id
    rename_column :boards_filters, :collection_id, :board_id
  end
end
