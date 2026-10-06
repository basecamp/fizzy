class AddAuthorizationCodeJtiToIdentityAccessTokens < ActiveRecord::Migration[8.2]
  def change
    add_column :identity_access_tokens, :authorization_code_jti, :string
    add_index :identity_access_tokens, :authorization_code_jti, unique: true
  end
end
