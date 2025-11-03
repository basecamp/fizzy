class CreateIdentityMagicLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :magic_links do |t|
      t.string :code, index: { unique: true }, null: false
      t.belongs_to :membership, null: false, foreign_key: true
      t.datetime :expires_at, index: true, null: false

      t.timestamps
    end
  end
end
