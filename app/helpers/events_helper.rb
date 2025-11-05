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

    def event_action_sentence(event)
      if event.action.comment_created?
        comment_event_action_sentence(event)
      else
        card_event_action_sentence(event)
      end
    end

    def comment_event_action_sentence(event)
      "#{event_creator_name(event)} commented on #{event_card_title(event.eventable.card)}".html_safe
    end

    def event_creator_name(event)
      tag.span data: { creator_id: event.creator.id } do
        safe_join([
          tag.span("You", data: { only_visible_to_you: true }),
          tag.span(h(event.creator.name), data: { only_visible_to_others: true })
        ])
      end
    end

    def card_event_action_sentence(event)
      card = event.eventable

      case event.action
      when "card_assigned"
        if event.assignees.include?(Current.user)
          "#{event_creator_name(event)} will handle #{event_card_title(card)}"
        else
          "#{event_creator_name(event)} assigned #{h event.assignees.pluck(:name).to_sentence} to #{event_card_title(card)}"
        end
      when "card_unassigned"
        "#{event_creator_name(event)} unassigned #{h(event.assignees.include?(Current.user) ? "yourself" : event.assignees.pluck(:name).to_sentence)} from #{event_card_title(card)}"
      when "card_published"
        "#{event_creator_name(event)} added #{event_card_title(card)}"
      when "card_closed"
        "#{event_creator_name(event)} moved #{event_card_title(card)} to “Done”"
      when "card_reopened"
        "#{event_creator_name(event)} reopened #{event_card_title(card)}"
      when "card_postponed"
        "#{event_creator_name(event)} moved #{event_card_title(card)} to “Not Now”"
      when "card_auto_postponed"
        "#{event_card_title(card)} was closed as “Not Now” due to inactivity"
      when "card_resumed"
        "#{event_creator_name(event)} resumed #{event_card_title(card)}"
      when "card_title_changed"
        "#{event_creator_name(event)} renamed #{event_card_title(card)} (was: “#{h event.particulars.dig('particulars', 'old_title')}”)"
      when "card_collection_changed"
        "#{event_creator_name(event)} moved #{event_card_title(card)} to “#{h event.particulars.dig('particulars', 'new_collection')}”"
      when "card_triaged"
        "#{event_creator_name(event)} moved #{event_card_title(card)} to “#{h event.particulars.dig('particulars', 'column')}”"
      when "card_sent_back_to_triage"
        "#{event_creator_name(event)} moved #{event_card_title(card)} back to “Maybe?”"
      end&.html_safe
    end

    def event_card_title(card)
      tag.span card.title, class: "txt-underline"
    end

    def event_due_date(event)
      event.particulars.dig("particulars", "due_date").to_date.strftime("%B %-d")
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
      when "card_collection_changed"
        "move"
      else
        "person"
      end
    end
end
