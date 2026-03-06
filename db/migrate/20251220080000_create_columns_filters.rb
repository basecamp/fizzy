class CreateColumnsFilters < ActiveRecord::Migration[8.0]
  def change
    create_table :columns_filters, id: false do |t|
      t.uuid :column_id, null: false
      t.uuid :filter_id, null: false
      t.index :column_id
      t.index :filter_id
    end
  end
end
