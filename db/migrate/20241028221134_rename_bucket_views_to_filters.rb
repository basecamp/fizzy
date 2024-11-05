class RenameBucketViewsToFilters < ActiveRecord::Migration[8.0]
  def change
    rename_table :bucket_views, :filters

    remove_index :filters, %i[ bucket_id creator_id filters ], unique: true
    remove_index :filters, :creator_id

    remove_column :filters, :bucket_id

    rename_column :filters, :filters, :params

    add_index :filters, %i[ creator_id params ], unique: true
  end
end
