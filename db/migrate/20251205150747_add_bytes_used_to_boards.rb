class AddBytesUsedToBoards < ActiveRecord::Migration[8.2]
  def change
    add_column :boards, :bytes_used, :bigint, default: 0
  end
end
