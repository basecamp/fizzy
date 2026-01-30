class CreateCardBubbleUps < ActiveRecord::Migration[8.2]
  def change
    create_table :card_bubble_ups, id: :uuid do |t|
      t.references :account, null: false, type: :uuid
      t.references :card, null: false, type: :uuid
      t.datetime :resurface_at

      t.timestamps
    end
  end
end
