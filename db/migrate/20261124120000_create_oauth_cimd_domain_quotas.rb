# The open tier's registration quota for Client ID Metadata Documents: one row
# per registrable domain, charged inside the transaction that creates the
# client, so a creation that rolls back refunds itself. A cache counter can't
# hold this: the counters fail open, and a flushed cache would reset the cap.
class CreateOauthCimdDomainQuotas < ActiveRecord::Migration[8.2]
  def change
    create_table :oauth_cimd_domain_quotas, id: :uuid do |t|
      t.string :registrable_domain, null: false
      t.datetime :window_started_at, null: false
      t.integer :created_count, null: false, default: 0
      t.timestamps

      t.index :registrable_domain, unique: true
    end
  end
end
