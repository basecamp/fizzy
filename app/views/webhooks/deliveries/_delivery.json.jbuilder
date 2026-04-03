json.cache! delivery do
  json.(delivery, :id, :state)
  json.created_at delivery.created_at.utc
  json.updated_at delivery.updated_at.utc

  request_headers = delivery.request&.dig("headers")&.except("X-Webhook-Signature")
  if request_headers.present?
    json.request do
      json.headers request_headers
    end
  else
    json.request nil
  end

  response = delivery.response&.with_indifferent_access
  if response.present?
    json.response do
      json.code response[:code]
      json.error response[:error]
    end
  else
    json.response nil
  end

  json.event delivery.event, partial: "webhooks/deliveries/event", as: :event
end
