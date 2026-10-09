json.cache! [ webhook, webhook.board ] do
  json.(webhook, :id, :name, :active, :subscribed_actions)
  json.created_at webhook.created_at.utc
  json.url board_webhook_url(webhook.board, webhook)

  json.board webhook.board, partial: "boards/board", as: :board
end

# A webhook's signing secret lets its holder forge deliveries, and its URL is
# often itself a credential (Slack, Campfire). An OAuth grant gets both once,
# when it creates the webhook, the way GitHub and Stripe hand out webhook
# secrets. After that they stay with people and personal access tokens, so an
# app keeps no credential it didn't make once it's disconnected. Kept outside
# the cache because the answer depends on the caller.
if local_assigns[:reveal_credentials] || !oauth_grant?
  json.signing_secret webhook.signing_secret
  json.payload_url webhook.url
end
