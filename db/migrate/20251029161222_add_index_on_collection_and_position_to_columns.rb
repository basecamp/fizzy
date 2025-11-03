class AddIndexOnCollectionAndPositionToColumns < ActiveRecord::Migration[8.2]
  def change
    add_index :columns, [ :collection_id, :position ]
  end
end
