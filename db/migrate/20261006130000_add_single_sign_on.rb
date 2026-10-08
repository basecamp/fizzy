class AddSingleSignOn < ActiveRecord::Migration[8.2]
  def change
    create_table :identity_single_sign_on_links, id: :uuid do |t|
      t.uuid :identity_id, null: false
      t.string :issuer, null: false, collation: exact_collation
      t.string :subject, null: false, collation: exact_collation

      t.timestamps

      t.index [ :identity_id, :issuer ], unique: true
      t.index [ :issuer, :subject ], unique: true
    end

    add_column :sessions, :single_sign_on_authenticated_at, :datetime
    # SQLite rejects `size:`, and this limit gives a MySQL `MEDIUMTEXT` column.
    add_column :sessions, :single_sign_on_groups, :text, limit: 16.megabytes - 1
    add_column :accounts, :single_sign_on_group, :string, collation: exact_collation
  end

  private
    # The default MySQL collation ignores case and accents, but OIDC identifiers and group names must match exactly.
    def exact_collation
      "utf8mb4_0900_bin" unless connection.adapter_name == "SQLite"
    end
end
