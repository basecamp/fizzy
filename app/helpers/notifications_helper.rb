module NotificationsHelper
  def notification_title(notification)
    title = card_title(notification.card)

    if notification.resource.is_a? Comment
      "RE: " + title
    elsif notification_event_action(notification) == "assigned"
      "Assigned to you: " + title
    else
      title
    end
  end

  def notification_body(notification)
    name = notification.creator.name

    case notification_event_action(notification)
    when "closed" then "Closed by #{name}"
    when "published" then "Added by #{name}"
    else name
    end
  end

  def notification_tag(notification, &)
    tag.div id: dom_id(notification), class: "notification tray__item border-radius flex txt-normal" do
      concat(
        link_to(notification.resource,
          class: "notification__content border-radius shadow fill-white flex align-start txt-align-start gap flex-item-grow max-width border txt-ink",
          data: { action: "click->dialog#close", turbo_frame: "_top" },
          &)
      )
      concat(notification_mark_read_button(notification))
    end
  end

  def notification_mark_read_button(notification)
    button_to mark_read_notification_path(notification),
      class: "notification__unread_indicator btn borderless",
      title: "Mark as read",
      data: { turbo_frame: "_top" } do
        concat(image_tag("remove-med.svg", class: "unread_icon", size: 12, aria: { hidden: true }))
        concat(tag.span("Mark as read", class: "for-screen-reader"))
    end
  end

  def notifications_next_page_link(page)
    unless @page.last?
      tag.div id: "next_page", data: { controller: "fetch-on-visible", fetch_on_visible_url_value: notifications_path(page: @page.next_param) }
    end
  end

  private
    def notification_event_action(notification)
      if notification_is_for_initial_assignement?(notification)
        "assigned"
      else
        notification.event.action
      end
    end

    def notification_is_for_initial_assignement?(notification)
      notification.event.action == "published" && notification.card.assigned_to?(notification.user)
    end
end
