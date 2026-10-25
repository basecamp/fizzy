# Each step is skipped when it's already done, so a run that stopped partway
# (MySQL commits each DDL statement on its own) can simply be run again.
class AddAuthorizationCodeJtiToIdentityAccessTokens < ActiveRecord::Migration[8.2]
  def change
    add_column :identity_access_tokens, :authorization_code_jti, :string, if_not_exists: true
    add_index :identity_access_tokens, :authorization_code_jti, unique: true, if_not_exists: true
  end
end
