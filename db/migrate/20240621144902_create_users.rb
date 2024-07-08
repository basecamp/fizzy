class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.references :organization, null: false, foreign_key: true

      t.citext :name, null: false
      t.citext :email_address, null: false, index: { unique: true }
      t.string :password_digest, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end
  end
end
