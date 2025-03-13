module NotificationsHelper
  def notification_title(notification)
    title = notification.bubble.title

    if notification.resource.is_a? Comment
      "RE: " + title
    elsif (assignees = notification_event_assignees(notification))
      if assignees.include?(Current.user)
        "Assigned to you: " + title
      else
        "Assigned to #{assignees.first.name}: " + title
      end
    else
      title
    end
  end

  def notification_body(notification)
    name = notification.creator.name

    case notification_event_action(notification)
    when "popped" then "Popped by #{name}"
    when "published" then "Added by #{name}"
    else name
    end
  end

  def notification_tag(notification, &)
    tag.div id: dom_id(notification), class: "notification border-radius flex position-relative" do
      concat(
        link_to(notification.resource,
          class: "notification__content border-radius pad shadow fill-white flex align-start txt-align-start gap flex-item-grow max-width",
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
      notification.event.action == "published" && notification.bubble.assigned_to?(notification.user)
    end

    def notification_event_assignees(notification)
      notification_event_action(notification) == "assigned" && notification.event.assignees.presence
    end
end
