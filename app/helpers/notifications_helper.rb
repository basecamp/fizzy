module NotificationsHelper
  def event_notification_title(event)
    case event_notification_action(event)
    when "comment_created" then "RE: #{card_notification_title(event.eventable.card)}"
    when "card_assigned" then "Assigned to #{event.assignees.pluck(:name).to_sentence}: #{card_notification_title(event.eventable)}"
    else card_notification_title(event.eventable)
    end
  end

  def event_notification_body(event)
    name = event.creator.name

    case event_notification_action(event)
    when "card_closed" then "Closed by #{name}"
    when "card_published" then "Added by #{name}"
    when "comment_created" then comment_notification_body(event)
    else name
    end
  end

  def notification_tag(notification, &)
    tag.div id: dom_id(notification), class: "tray__item" do
      concat(
        link_to(notification,
          class: [ "card card--notification", { "card--closed": notification.card.closed? } ],
          data: { action: "click->dialog#close", turbo_frame: "_top" },
          style: { "--card-color:": notification.card.color },
          &)
      )
      concat(notification_mark_read_button(notification))
    end
  end

  def notification_mark_read_button(notification)
    button_to read_notification_path(notification),
        class: "card__notification-unread-indicator btn btn--circle borderless",
        title: "Mark as read",
        data: { turbo_frame: "_top" } do
      concat(icon_tag("remove-med"))
      concat(tag.span("Mark as read", class: "for-screen-reader"))
    end
  end

  def notifications_next_page_link(page)
    unless @page.last?
      tag.div id: "next_page", data: { controller: "fetch-on-visible", fetch_on_visible_url_value: notifications_path(page: @page.next_param) }
    end
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
      "#{strip_tags(comment.body_html).blank? ? "#{event.creator.name} replied" : "#{event.creator.name}:" } #{strip_tags(comment.body_html).truncate(200)}"
    end

    def card_notification_title(card)
      card.title.presence || "Card #{card.id}"
    end
end
