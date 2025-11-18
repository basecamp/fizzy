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
    when "card_board_changed", "card_triaged", "card_postponed"
      "move"
    else
      "person"
    end
  end
end
