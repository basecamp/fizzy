class AddRefreshTokenExpiresAtToIdentityAccessTokens < ActiveRecord::Migration[8.2]
  def up
    add_column :identity_access_tokens, :refresh_token_expires_at, :datetime
    add_index :identity_access_tokens, :refresh_token_expires_at

    # Grants issued before this have been idle since their last rotation.
    grants = Class.new(ActiveRecord::Base) { self.table_name = "identity_access_tokens" }
    grants.where.not(oauth_client_id: nil).find_each do |grant|
      grant.update_columns refresh_token_expires_at: grant.updated_at + 90.days
    end
  end

  def down
    remove_index :identity_access_tokens, :refresh_token_expires_at
    remove_column :identity_access_tokens, :refresh_token_expires_at
  end
end
