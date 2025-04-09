class RenameBubblesToCards < ActiveRecord::Migration[8.1]
  def change
    # Tables
    rename_table "bubbles", "cards"
    rename_table "bubble_engagements", "card_engagements"
    rename_table "pops", "closures"
    rename_table "pop_reasons", "closure_reasons"
    rename_table "buckets", "collections"
    rename_table "buckets_filters", "collections_filters"

    # Columns
    rename_column "assignments", "bubble_id", "card_id"
    rename_column "card_engagements", "bubble_id", "card_id"
    rename_column "events", "bubble_id", "card_id"
    rename_column "messages", "bubble_id", "card_id"
    rename_column "notifications", "bubble_id", "card_id"
    rename_column "pins", "bubble_id", "card_id"
    rename_column "closures", "bubble_id", "card_id"
    rename_column "taggings", "bubble_id", "card_id"
    rename_column "watches", "bubble_id", "card_id"

    rename_column "cards", "bucket_id", "collection_id"
    rename_column "accesses", "bucket_id", "collection_id"
    rename_column "collections_filters", "bucket_id", "collection_id"

    # Indexes
    rename_index "assignments", "index_assignments_on_bubble_id", "index_assignments_on_card_id"
    rename_index "card_engagements", "index_bubble_engagements_on_bubble_id", "index_card_engagements_on_card_id"
    rename_index "events", "index_events_on_bubble_id", "index_events_on_card_id"
    rename_index "messages", "index_messages_on_bubble_id", "index_messages_on_card_id"
    rename_index "notifications", "index_notifications_on_bubble_id", "index_notifications_on_card_id"
    rename_index "pins", "index_pins_on_bubble_id", "index_pins_on_card_id"
    rename_index "pins", "index_pins_on_bubble_id_and_user_id", "index_pins_on_card_id_and_user_id"
    rename_index "closures", "index_pops_on_bubble_id", "index_closures_on_card_id"
    rename_index "closures", "index_pops_on_bubble_id_and_created_at", "index_closures_on_card_id_and_created_at"
    rename_index "watches", "index_watches_on_bubble_id", "index_watches_on_card_id"
    rename_index "taggings", "index_taggings_on_bubble_id_and_tag_id", "index_taggings_on_card_id_and_tag_id"

    rename_index "accesses", "index_accesses_on_bucket_id", "index_accesses_on_collection_id"
    rename_index "accesses", "index_accesses_on_bucket_id_and_user_id", "index_accesses_on_collection_id_and_user_id"
    rename_index "collections_filters", "index_buckets_filters_on_bucket_id", "index_collections_filters_on_collection_id"

    # Search tables
    execute <<~SQL
      CREATE VIRTUAL TABLE cards_search_index USING fts5(title);
      INSERT INTO cards_search_index(title) SELECT title FROM bubbles_search_index;
    SQL

    execute <<~SQL
      DROP TABLE bubbles_search_index;
    SQL
  end
end
