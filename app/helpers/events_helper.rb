module EventsHelper
  def event_columns(event_type, day_timeline)
    case event_type
    when "added"
      events = day_timeline.events.where(action: [ "card_published", "card_reopened" ])
      {
        title: event_column_title("Added", events.count, day_timeline.day),
        index: 1,
        events: events
      }
    when "closed"
      events = day_timeline.events.where(action: "card_closed")
      {
        title: event_column_title("Closed", events.count, day_timeline.day),
        index: 3,
        events: events
      }
    else
      events = day_timeline.events.where.not(action: [ "card_published", "card_closed", "card_reopened" ])
      {
        title: event_column_title("Updated", events.count, day_timeline.day),
        index: 2,
        events: events
      }
    end
  end

  private

  def event_column_title(base_title, count, day)
    date_tag = local_datetime_tag day, style: :agoorweekday
    if count > 0
      "#{h base_title} #{date_tag} <span class='font-weight-normal'>(#{h count})</span>".html_safe
    else
      "#{h base_title} #{date_tag}".html_safe
    end
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

  def event_next_page_link(next_day)
    if next_day
      tag.div id: "next_page",
        data: { controller: "fetch-on-visible",
                fetch_on_visible_url_value: events_days_path(
                  day: next_day.strftime("%Y-%m-%d"),
                  **@filter.as_params
                ) }
    end
  end

  def event_action_sentence(event)
    if event.action.comment_created?
      comment_event_action_sentence(event)
    else
      card_event_action_sentence(event)
    end
  end

  def comment_event_action_sentence(event)
    "#{h event_creator_name(event) } commented on <span style='color: var(--card-color)'>#{h event.eventable.card.title }</span>".html_safe
  end

  def event_creator_name(event)
    event.creator == Current.user ? "You" : event.creator.name
  end

  def card_event_action_sentence(event)
    card = event.eventable
    title = card.title

    case event.action
    when "card_assigned"
      if event.assignees.include?(Current.user)
        "#{h event_creator_name(event) } will handle <span style='color: var(--card-color)'>#{h title }</span>".html_safe
      else
        "#{h event_creator_name(event) } assigned #{h event.assignees.pluck(:name).to_sentence } to <span style='color: var(--card-color)'>#{h title }</span>".html_safe
      end
    when "card_unassigned"
      "#{h event_creator_name(event) } unassigned #{ h(event.assignees.include?(Current.user) ? "yourself" : event.assignees.pluck(:name).to_sentence) } from <span style='color: var(--card-color)'>#{h title }</span>".html_safe
    when "card_published"
      "#{h event_creator_name(event) } added <span style='color: var(--card-color)'>#{h title }</span>".html_safe
    when "card_closed"
      "#{h event_creator_name(event) } closed <span style='color: var(--card-color)'>#{h title }</span>".html_safe
    when "card_reopened"
      "#{h event_creator_name(event) } reopened <span style='color: var(--card-color)'>#{h title }</span>".html_safe
    when "card_staged"
      "#{h event_creator_name(event)} moved <span style='color: var(--card-color)'>#{h title }</span> to the #{h event.stage_name} stage".html_safe
    when "card_unstaged"
      "#{h event_creator_name(event)} moved <span style='color: var(--card-color)'>#{h title }</span> out ofthe #{h event.stage_name} stage".html_safe
    when "card_due_date_added"
      "#{h event_creator_name(event)} set the date to #{h event.particulars.dig('particulars', 'due_date').to_date.strftime('%B %-d')} on <span style='color: var(--card-color)'>#{h title }</span>".html_safe
    when "card_due_date_changed"
      "#{h event_creator_name(event)} changed the date to #{h event.particulars.dig('particulars', 'due_date').to_date.strftime('%B %-d')} on <span style='color: var(--card-color)'>#{h title }</span>".html_safe
    when "card_due_date_removed"
      "#{h event_creator_name(event)} removed the date on <span style='color: var(--card-color)'>#{h title }</span>".html_safe
    when "card_title_changed"
      "#{h event_creator_name(event)} renamed <span style='color: var(--card-color)'>#{h title }</span> (was: '#{h event.particulars.dig('particulars', 'old_title')})'".html_safe
    when "card_collection_changed"
      "#{h event_creator_name(event)} moved <span style='color: var(--card-color)'>#{h title }</span> to '#{h event.particulars.dig('particulars', 'new_collection')}'".html_safe
    end
  end

  def event_action_icon(event)
    case event.action
    when "card_assigned"
      "assigned"
    when "card_unassigned"
      "minus"
    when "card_staged"
      "bolt"
    when "card_unstaged"
      "bolt"
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
