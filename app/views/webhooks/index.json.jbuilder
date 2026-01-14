json.array! @webhooks do |webhook|
  json.(webhook, :id, :name, :url, :subscribed_actions)
  json.created_at webhook.created_at.utc
end
