class AddAaguidAndBackedUpToIdentityCredentials < ActiveRecord::Migration[8.2]
  def change
    add_column :identity_credentials, :aaguid, :string
    add_column :identity_credentials, :backed_up, :boolean
  end
end
