class IntroduceBucketables < ActiveRecord::Migration[8.0]
  def change
    add_reference :buckets, :bucketable, polymorphic: true, null: false
    remove_column :buckets, :name
    remove_reference :buckets, :creator
  end
end
