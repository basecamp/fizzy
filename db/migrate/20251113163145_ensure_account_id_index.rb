class EnsureAccountIdIndex < ActiveRecord::Migration[8.2]
  def change
    remove_index :accesses, :accessed_at
    add_index :accesses, [:account_id, :accessed_at]

    remove_index :account_join_codes, :code
    add_index :account_join_codes, [:account_id, :code], unique: true

    add_index :assignments, :account_id

    remove_index :board_publications, :key
    add_index :board_publications, [:account_id, :key]

    add_index :boards, :account_id

    add_index :card_activity_spikes, :account_id

    remove_index :card_engagements, :status
    add_index :card_engagements, [:account_id, :status]

    add_index :card_goldnesses, :account_id

    add_index :card_not_nows, :account_id

    remove_index :cards, [:last_active_at, :status]
    add_index :cards, [:account_id, :last_active_at, :status]

    add_index :closures, :account_id

    add_index :columns, :account_id

    add_index :comments, :account_id

    add_index :entropies, :account_id

    remove_index :events, :action
    add_index :events, [:account_id, :action]

    add_index :filters, :account_id

    add_index :mentions, :account_id

    add_index :notification_bundles, :account_id

    add_index :notifications, :account_id

    add_index :pins, :account_id

    add_index :push_subscriptions, :account_id
    remove_index :push_subscriptions, :endpoint # duplicative because we always query [user_id, endpoint]
    remove_index :push_subscriptions, [:endpoint, :p256dh_key, :auth_key] # duplicative and not necessary
    remove_index :push_subscriptions, :user_agent # not necessary
    remove_index :push_subscriptions, :user_id # duplicative of [user_id, endpoint]

    add_index :reactions, :account_id

    add_index :search_queries, :account_id

    add_index :steps, :account_id

    add_index :taggings, :account_id

    remove_index :tags, :title
    add_index :tags, [:account_id, :title], unique: true

    add_index :user_settings, :account_id

    remove_index :users, :role
    add_index :users, [:account_id, :role]

    add_index :watches, :account_id

    add_index :webhook_delinquency_trackers, :account_id

    add_index :webhook_deliveries, :account_id

    # For webhooks, I'm making an additional change to collapse board_id and subscribed_actions into
    # a single index, since Triggerable only queries for `subscribed_actions` in conjunction with
    # `board_id`.
    add_index :webhooks, :account_id
    remove_index :webhooks, :subscribed_actions
    add_index :webhooks, [:board_id, :subscribed_actions], length: { subscribed_actions: 255 }
    remove_index :webhooks, :board_id

    # Rails models
    add_index :action_text_rich_texts, :account_id
    add_index :active_storage_attachments, :account_id
    add_index :active_storage_blobs, :account_id
    add_index :active_storage_variant_records, :account_id
  end
end
