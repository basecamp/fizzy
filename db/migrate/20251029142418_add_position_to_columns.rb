class AddPositionToColumns < ActiveRecord::Migration[8.2]
  def change
    add_column :columns, :position, :integer, default: 0

    execute "UPDATE columns SET position = 0"

    change_column_null :columns, :position, false
  end
end
