json.cache! @event do
  json.(@event, :id, :action)
  json.created_at @event.created_at.utc

  json.eventable do
    case @event.eventable
    when Card then json.partial! "cards/card", card: @event.eventable
    when Comment then json.partial! "cards/comments/comment", comment: @event.eventable
    end
  end

  json.board do
    json.partial! "boards/board", locals: { board: @event.board }
  end

  json.creator do
    json.partial! "users/user", user: @event.creator
  end
end
