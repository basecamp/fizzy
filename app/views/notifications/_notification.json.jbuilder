json.cache! notification do
  json.(notification, :id, :unread_count)
  json.read notification.read?
  json.read_at notification.read_at&.utc
  json.created_at notification.created_at.utc
  json.source_type notification.source_type.underscore

  json.partial! "notifications/notification/#{notification.source_type.underscore}/body", notification: notification

  json.creator notification.creator, partial: "users/user", as: :user

  json.card do
    json.(notification.card, :id, :number, :title, :status)
    json.board_name notification.card.board.name
    json.closed notification.card.closed?
    json.postponed notification.card.postponed?
    json.url card_url(notification.card)
    json.column notification.card.column, partial: "columns/column", as: :column if notification.card.column
  end

  json.url notification_url(notification)
end
