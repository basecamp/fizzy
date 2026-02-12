json.cache! notification do
  json.(notification, :id, :unread_count)
  json.read notification.read?
  json.read_at notification.read_at&.utc
  json.created_at notification.created_at.utc

  json.partial! "notifications/notification/#{notification.source_type.underscore}/body", notification: notification

  json.creator notification.creator, partial: "users/user", as: :user

  json.card do
    json.(notification.card, :id, :title, :status)
    json.url card_url(notification.card)
  end

  json.url notification_url(notification)
end
