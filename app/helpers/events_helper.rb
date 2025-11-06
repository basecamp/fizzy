module EventsHelper
  def event_columns(event_type, day_timeline)
    case event_type
    when "added"
      events = day_timeline.events.where(action: [ "card_published", "card_reopened" ])
      full_events_count = events.count
      {
        title: event_column_title("Added", full_events_count, day_timeline.day),
        index: 1,
        events: events.limit(100).load,
        full_events_count: full_events_count
      }
    when "closed"
      events = day_timeline.events.where(action: "card_closed")
      full_events_count = events.count
      {
        title: event_column_title("Closed", full_events_count, day_timeline.day),
        index: 3,
        events: events.limit(100).load,
        full_events_count: full_events_count
      }
    else
      events = day_timeline.events.where.not(action: [ "card_published", "card_closed", "card_reopened" ])
      full_events_count = events.count
      {
        title: event_column_title("Updated", full_events_count, day_timeline.day),
        index: 2,
        events: events.limit(100).load,
        full_events_count: full_events_count
      }
    end
  end

  private
    def event_column_title(base_title, count, day)
      date_tag = local_datetime_tag day, style: :agoorweekday
      parts = [ base_title, date_tag ]
      parts << tag.span("(#{count})", class: "font-weight-normal") if count > 0
      safe_join(parts, " ")
    end

    def event_column(event)
      case event.action
      when "card_closed"
        3
      when "card_published", "card_reopened"
        1
      else
        2
      end
    end

    def event_cluster_tag(hour, col, &)
      row = 25 - hour
      tag.div class: "events__time-block", style: "grid-area: #{row}/#{col}", &
    end

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
end
