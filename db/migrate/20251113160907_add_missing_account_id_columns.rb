class AddMissingAccountIdColumns < ActiveRecord::Migration[8.2]
  MISSING_TABLES= %w[
    accesses
    assignments
    board_publications
    card_activity_spikes
    card_engagements
    card_goldnesses
    card_not_nows
    closures
    entropies
    mentions
    pins
    reactions
    search_queries
    taggings
    user_settings
    watches
    webhook_delinquency_trackers
    webhook_deliveries

    action_text_rich_texts
    active_storage_attachments
    active_storage_blobs
    active_storage_variant_records
  ]

  NOT_REQUIRED_TABLES = %w[
    account_join_codes
    boards
    cards
    columns
    comments
    events
    filters
    notification_bundles
    notifications
    push_subscriptions
    steps
    tags
    users
    webhooks
  ]

  def change
    MISSING_TABLES.each do |table|
      add_column table, "account_id", :uuid, null: false
    end

    NOT_REQUIRED_TABLES.each do |table|
      change_column table, "account_id", :uuid, null: false
    end
  end
end
