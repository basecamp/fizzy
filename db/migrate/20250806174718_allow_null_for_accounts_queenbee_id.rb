class AllowNullForAccountsQueenbeeId < ActiveRecord::Migration[8.1]
  def change
    change_column_null :accounts, :queenbee_id, true
  end
end
