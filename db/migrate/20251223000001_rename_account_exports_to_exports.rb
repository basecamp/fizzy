class RenameAccountExportsToExports < ActiveRecord::Migration[8.2]
  def change
    rename_table :account_exports, :exports
    add_column :exports, :type, :string
    add_index :exports, :type
  end
end
