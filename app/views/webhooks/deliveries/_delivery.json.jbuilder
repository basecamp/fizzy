json.cache! delivery do
  json.(delivery, :id, :state)
  json.created_at delivery.created_at.utc
  json.updated_at delivery.updated_at.utc

  json.request delivery.sanitized_request
  json.response delivery.response_summary

  json.event delivery.event, partial: "webhooks/deliveries/event", as: :event
end
