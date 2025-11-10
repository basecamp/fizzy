module EventsHelper
  def event_action_icon(event)
    case event.action
    when "card_assigned"
      "assigned"
    when "card_unassigned"
      "minus"
    when "comment_created"
      "comment"
    when "card_title_changed"
      "rename"
    when "card_board_changed"
      "move"
    else
      "person"
    end
  end

  def events_at_hour_container(column, hour, &block)
    tag.div class: "events__time-block", style: "grid-area: #{25 - hour}/#{column.index}", &block
  end
end
