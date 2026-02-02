class DropCardEngagements < ActiveRecord::Migration[8.2]
  def up
    drop_table :card_engagements
  end

  def down
    create_table :card_engagements, id: :uuid do |t|
      t.references :account, type: :uuid, null: false
      t.references :card, type: :uuid, null: false, index: true
      t.string :status, null: false
      t.timestamps
    end

    add_index :card_engagements, [ :account_id, :status ]
  end
end
