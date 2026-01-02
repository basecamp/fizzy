class CreateCardLinks < ActiveRecord::Migration[8.2]
  def change
    create_table :card_links, id: :uuid do |t|
      t.references :source_card, null: false, type: :uuid, index: true
      t.references :target_card, null: false, type: :uuid, index: true
      t.integer :link_type, null: false, default: 0
      t.timestamps
    end

    # Foreign keys with cascade delete
    add_foreign_key :card_links, :cards, column: :source_card_id, on_delete: :cascade
    add_foreign_key :card_links, :cards, column: :target_card_id, on_delete: :cascade

    # Unique constraint including link_type
    add_index :card_links, [:source_card_id, :target_card_id, :link_type],
              unique: true, name: "index_card_links_unique"

    # Prevent self-linking at database level
    add_check_constraint :card_links, "source_card_id != target_card_id", name: "no_self_links"
  end
end
