# This migration comes from audits1984 (originally 20260126000000)
class CreateAuditorTokens < ActiveRecord::Migration[7.0]
  def change
    create_table :audits1984_auditor_tokens do |t|
      t.uuid :auditor_id, null: false, index: { unique: true }
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false

      t.timestamps

      t.index :token_digest, unique: true
    end
  end
end
