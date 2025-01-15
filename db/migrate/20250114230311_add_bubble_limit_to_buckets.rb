class AddBubbleLimitToBuckets < ActiveRecord::Migration[8.1]
  def change
    add_column :buckets, :bubble_limit, :integer, default: 10, null: false
  end
end
