json.cache! @event do
  json.(@event, :id, :action)
  json.created_at @event.created_at.utc

  json.eventable do
    case @event.eventable
    when Card then json.partial! "cards/card", card: @event.eventable
    when Comment then json.partial! "cards/comments/comment", comment: @event.eventable
    end
  end

  json.board @event.board, partial: "boards/board", as: :board
  json.creator @event.creator, partial: "users/user", as: :user
end
