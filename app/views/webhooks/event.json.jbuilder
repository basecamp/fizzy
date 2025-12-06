json.cache! @event do
  json.(@event, :id, :action)
  json.created_at @event.created_at.utc
  json.event_type @event.action

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

  # Special handling for user.mentioned events
  if @event.action == "user.mentioned" && @event.eventable.is_a?(Comment)
    # Find the mention that triggered this event
    mentioned_user_id = @event.particulars&.dig("mentioned_user_id")
    if mentioned_user_id
      mention = @event.eventable.mentions.find_by(mentionee_id: mentioned_user_id)
      if mention
        mentionee = mention.mentionee
        json.target do
          json.id mentionee.id
          json.email mentionee.identity&.email_address
        end
      end
    end
  end

  # Special handling for card.linked events
  if @event.action == "card.linked" && @event.particulars
    linked_card_number = @event.particulars["linked_card_id"]
    linked_card_title = @event.particulars["linked_card_title"]
    if linked_card_number
      json.linked_card do
        json.id linked_card_number
        json.title linked_card_title
      end
    end
  end
end

