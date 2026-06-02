class AddCustomColumnNamesToBoards < ActiveRecord::Migration[8.2]
  def change
    add_column :boards, :triage_column_name, :string, null: false, default: "Maybe?"
    add_column :boards, :postponed_column_name, :string, null: false, default: "Not Now"
    add_column :boards, :closed_column_name, :string, null: false, default: "Done"
  end
end
