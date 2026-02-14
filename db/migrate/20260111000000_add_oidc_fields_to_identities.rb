class AddOidcFieldsToIdentities < ActiveRecord::Migration[8.2]
  def change
    add_column :identities, :oidc_subject, :string, limit: 255
    add_column :identities, :oidc_provider, :string, limit: 255

    add_index :identities, [:oidc_subject, :oidc_provider],
      unique: true,
      name: "index_identities_on_oidc_subject_and_provider"
  end
end
