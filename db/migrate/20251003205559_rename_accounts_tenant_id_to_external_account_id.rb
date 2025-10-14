class RenameAccountsTenantIdToExternalAccountId < ActiveRecord::Migration[8.1]
  def change
    rename_column :accounts, :tenant_id, :external_account_id
  end
end
