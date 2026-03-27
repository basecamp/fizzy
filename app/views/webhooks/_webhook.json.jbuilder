json.cache! [ webhook, webhook.board ] do
  json.(webhook, :id, :name, :active, :signing_secret, :subscribed_actions)
  json.payload_url webhook.url
  json.created_at webhook.created_at.utc
  json.url board_webhook_url(webhook.board, webhook)

  json.board webhook.board, partial: "boards/board", as: :board
end
