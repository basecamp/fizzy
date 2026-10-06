class AddSingleSignOn < ActiveRecord::Migration[8.2]
  def change
    create_table :identity_single_sign_on_links, id: :uuid do |t|
      t.uuid :identity_id, null: false
      t.string :issuer, null: false
      t.string :subject, null: false

      t.timestamps

      t.index [ :identity_id, :issuer ], unique: true
      t.index [ :issuer, :subject ], unique: true
    end

    add_column :sessions, :single_sign_on_authenticated_at, :datetime
    add_column :sessions, :single_sign_on_groups, :text
    add_column :accounts, :single_sign_on_group, :string
  end
end
