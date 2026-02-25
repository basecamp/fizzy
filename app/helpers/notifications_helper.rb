module NotificationsHelper
  def event_notification_title(event)
    case event_notification_action(event)
    when "comment_created" then "RE: #{card_notification_title(event.eventable.card)}"
    else card_notification_title(event.eventable)
    end
  end

  def event_notification_body(event)
    creator = event.creator.name

    case event_notification_action(event)
    when "card_assigned" then "Assigned to #{event.assignees.none? ? "self" : event.assignees.pluck(:name).to_sentence}"
    when "card_unassigned" then "Unassigned by #{creator}"
    when "card_published" then "Added by #{creator}"
    when "card_closed" then "Moved to Done by #{creator}"
    when "card_reopened" then "Reopened by #{creator}"
    when "card_postponed" then "Moved to Not Now by #{creator}"
    when "card_auto_postponed" then "Moved to Not Now due to inactivity"
    when "card_title_changed" then "Renamed by #{creator}"
    when "card_board_changed" then "Moved by #{creator}"
    when "card_triaged" then "Moved to #{event.particulars.dig("particulars", "column")} by #{creator}"
    when "card_sent_back_to_triage" then "Moved back to Maybe? by #{creator}"
    when "comment_created" then comment_notification_body(event)
    else creator
    end
  end

  def notification_tag(notification, &)
    tag.div id: dom_id(notification), class: "tray__item tray__item--notification", data: {
      navigable_list_target: "item",
      card_id: notification.card.id
    } do
      link_to(notification,
        class: [ "card card--notification", { "card--closed": notification.card.closed? }, { "unread": !notification.read? } ],
        data: { turbo_frame: "_top", badge_target: "unread", action: "badge#update dialog#close" },
        style: { "--card-color:": notification.card.color },
        &)
    end
  end

  def notification_toggle_read_button(notification, url:)
    if notification.read?
      button_to url,
          method: :delete,
          class: "card__notification-unread-indicator btn btn--circle borderless",
          title: "Mark as unread",
          data: { action: "form#submit:stop badge#update:stop", form_target: "submit" },
          form: { data: { controller: "form" } } do
        concat(icon_tag("unseen"))
      end
    else
      button_to url,
          class: "card__notification-unread-indicator btn btn--circle borderless",
          title: "Mark as read",
          data: { action: "form#submit:stop badge#update:stop", form_target: "submit" },
          form: { data: { controller: "form" } } do
        concat(icon_tag("remove"))
        concat(tag.span(notification.unread_count, class: "badge-count")) if notification.unread_count > 1
      end
    end
  end

  def notifications_next_page_link(page)
    unless @page.last?
      tag.div id: "next_page", data: { controller: "fetch-on-visible", fetch_on_visible_url_value: notifications_path(page: @page.next_param) }
    end
  end

  def bundle_email_frequency_options_for(settings)
    options_for_select([
      [ "Never", "never" ],
      [ "Every few hours", "every_few_hours" ],
      [ "Every day", "daily" ],
      [ "Every week", "weekly" ]
    ], settings.bundle_email_frequency)
  end

  private
    def event_notification_action(event)
      if event.action.card_published? && event.eventable.assigned_to?(event.creator)
        "card_assigned"
      else
        event.action
      end
    end

    def comment_notification_body(event)
      comment = event.eventable
      comment.body.to_plain_text.truncate(200)
    end

    def card_notification_title(card)
      card.title.presence || "Card #{card.number}"
    end
end
