module EventsHelper
  def event_day_title(day)
    case
    when day.today?
      "Today"
    when day.yesterday?
      "Yesterday"
    else
      day.strftime("%A, %B %e")
    end
  end

  def event_column(event)
    case event.action
    when "closed"
      3
    when "published"
      1
    else
      2
    end
  end

  def event_cluster_tag(hour, col, &)
    row = 25 - hour
    tag.div class: "event__wrapper", style: "grid-area: #{row}/#{col}", &
  end

  def event_next_page_link(next_day)
    if next_day
      tag.div id: "next_page",
        data: { controller: "fetch-on-visible", fetch_on_visible_url_value: events_days_path(day: next_day.strftime("%Y-%m-%d")) }
    end
  end

  def render_event_grid_cells(day, columns: 4, rows: 24)
    safe_join((2..rows + 1).map do |row|
      (1..columns).map do |col|
        tag.div class: class_names("event__grid-item"), style: "grid-area: #{row}/#{col};"
      end
    end.flatten)
  end

  def render_column_headers(day = Date.current)
    start_time = day.beginning_of_day
    end_time = day.end_of_day

    accessible_events = Event.joins(card: :collection)
      .merge(Current.user.collections)
      .where(created_at: start_time..end_time)
      .where(cards: { collection_id: params[:collection_ids].presence || Current.user.collection_ids })

    headers = {
      "Added" => accessible_events.where(action: "published").count,
      "Updated" => nil,
      "Closed" => accessible_events.where(action: "closed").count
    }

    headers.map do |header, count|
      title = count&.positive? ? "#{header} (#{count})" : header
      content_tag(:h3, title, class: "event__grid-column-title position-sticky")
    end.join.html_safe
  end

  def event_action_sentence(event)
    case event.action
    when "assigned"
      if event.assignees.include?(Current.user)
        "#{ event.creator == Current.user ? "You" : event.creator.name } will handle <span style='color: var(--card-color)'>#{ card_title(event.card) }</span>".html_safe
      else
        "#{ event.creator == Current.user ? "You" : event.creator.name } assigned #{ event.assignees.pluck(:name).to_sentence } to <span style='color: var(--card-color)'>#{ card_title(event.card) }</span>".html_safe
      end
    when "unassigned"
      "#{ event.creator == Current.user ? "You" : event.creator.name } unassigned #{ event.assignees.pluck(:name).to_sentence } from <span style='color: var(--card-color)'>#{ card_title(event.card) }</span>".html_safe
    when "boosted"
      "#{ event.creator == Current.user ? "You" : event.creator.name } boosted <span style='color: var(--card-color)'>#{ card_title(event.card) }</span>".html_safe
    when "commented"
      "#{ event.creator == Current.user ? "You" : event.creator.name } commented on <span style='color: var(--card-color)'>#{ card_title(event.card) }</span>".html_safe
    when "published"
      "#{ event.creator == Current.user ? "You" : event.creator.name } added <span style='color: var(--card-color)'>#{ card_title(event.card) }</span>".html_safe
    when "closed"
      "#{ event.creator == Current.user ? "You" : event.creator.name } closed <span style='color: var(--card-color)'>#{ card_title(event.card) }</span>".html_safe
    when "staged"
      "#{event.creator == Current.user ? "You" : event.creator.name} changed the stage to #{event.stage_name} on <span style='color: var(--card-color)'>#{ card_title(event.card) }</span>".html_safe
    when "unstaged"
      "#{event.creator == Current.user ? "You" : event.creator.name} removed <span style='color: var(--card-color)'>#{ card_title(event.card) }</span> from the #{event.stage_name} stage".html_safe
    when "due_date_added"
      "#{event.creator == Current.user ? "You" : event.creator.name} set the date to #{event.particulars.dig('particulars', 'due_date').to_date.strftime('%B %-d')} on <span style='color: var(--card-color)'>#{ card_title(event.card) }</span>".html_safe
    when "due_date_changed"
      "#{event.creator == Current.user ? "You" : event.creator.name} changed the date to #{event.particulars.dig('particulars', 'due_date').to_date.strftime('%B %-d')} on <span style='color: var(--card-color)'>#{ card_title(event.card) }</span>".html_safe
    when "due_date_removed"
      "#{event.creator == Current.user ? "You" : event.creator.name} removed the date on <span style='color: var(--card-color)'>#{ card_title(event.card) }</span>"
    when "title_changed"
      "#{event.creator == Current.user ? "You" : event.creator.name} renamed  on <span style='color: var(--card-color)'>#{ card_title(event.card) }</span> (was: '#{event.particulars.dig('particulars', 'old_title')})'".html_safe
    end
  end

  def event_action_icon(event)
    case event.action
    when "assigned"
      "assigned"
    when "boosted"
      "thumb-up"
    when "staged"
      "bolt"
    when "unstaged"
      "bolt"
    when "commented"
      "comment"
    when "title_changed"
      "rename"
    else
      "person"
    end
  end
end
