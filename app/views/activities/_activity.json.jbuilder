json.(event, :id, :action)
json.created_at event.created_at.utc
json.description event.description_for(Current.user).to_plain_text
json.particulars event.api_particulars
json.url(
  case event.eventable
  when Comment then card_url(event.eventable.card, anchor: dom_id(event.eventable))
  else polymorphic_url(event.eventable)
  end
)
json.eventable_type event.eventable_type

json.eventable do
  case event.eventable
  when Card    then json.partial! "cards/card", card: event.eventable
  when Comment then json.partial! "cards/comments/comment", comment: event.eventable
  end
end

json.board event.board, partial: "boards/board", as: :board
json.creator event.creator, partial: "users/user", as: :user
