# A record of every authorization code redeemed, kept past the code's own
# lifetime, so a code can't be redeemed again once the grant it minted is gone
# (revoked by a replay, by the person, or by its app).
class CreateOauthRedeemedAuthorizationCodes < ActiveRecord::Migration[8.2]
  def change
    create_table :oauth_redeemed_authorization_codes, id: :uuid do |t|
      t.string :jti, null: false, limit: 36
      t.datetime :created_at, null: false

      t.index :jti, unique: true
      t.index :created_at
    end
  end
end
