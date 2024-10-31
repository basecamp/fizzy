class RenameBucketViewsToViews < ActiveRecord::Migration[8.0]
  def change
    rename_table :bucket_views, :views

    change_column_null :views, :bucket_id, true
    remove_index :views, %i[ bucket_id creator_id filters ], unique: true
    remove_index :views, :creator_id
    add_index :views, %i[ creator_id filters bucket_id ], unique: true
  end
end
