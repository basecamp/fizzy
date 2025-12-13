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
    when "card_assigned" then t("notifications.body.assigned_to", assignees: event.assignees.none? ? t("notifications.body.self") : event.assignees.pluck(:name).to_sentence)
    when "card_unassigned" then t("notifications.body.unassigned_by", creator: creator)
    when "card_published" then t("notifications.body.added_by", creator: creator)
    when "card_closed" then t("notifications.body.moved_to_done", creator: creator)
    when "card_reopened" then t("notifications.body.reopened_by", creator: creator)
    when "card_postponed" then t("notifications.body.moved_to_not_now", creator: creator)
    when "card_auto_postponed" then t("notifications.body.auto_postponed")
    when "card_title_changed" then t("notifications.body.renamed_by", creator: creator)
    when "card_board_changed" then t("notifications.body.moved_by", creator: creator)
    when "card_triaged" then t("notifications.body.moved_to_column", column: event.particulars.dig("particulars", "column"), creator: creator)
    when "card_sent_back_to_triage" then t("notifications.body.moved_back_to_triage", creator: creator)
    when "comment_created" then comment_notification_body(event)
    else creator
    end
  end

  def notification_tag(notification, &)
    tag.div id: dom_id(notification), class: "tray__item tray__item--notification", data: {
      navigable_list_target: "item",
      notifications_tray_target: "notification",
      card_id: notification.card.id,
      timestamp: notification.created_at.to_i
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
          title: t("notifications.buttons.mark_unread"),
          data: { action: "form#submit:stop badge#update:stop", form_target: "submit" },
          form: { data: { controller: "form" } } do
        concat(icon_tag("unseen"))
      end
    else
      button_to url,
          class: "card__notification-unread-indicator btn btn--circle borderless",
          title: t("notifications.buttons.mark_read"),
          data: { action: "form#submit:stop badge#update:stop", form_target: "submit" },
          form: { data: { controller: "form" } } do
        concat(icon_tag("remove"))
        concat(tag.span("1", class: "badge-count", data: { group_count: "" }))
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
      [ t("notifications.frequency.never"), "never" ],
      [ t("notifications.frequency.every_few_hours"), "every_few_hours" ],
      [ t("notifications.frequency.daily"), "daily" ],
      [ t("notifications.frequency.weekly"), "weekly" ]
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
      card.title.presence || t("notifications.body.card_number", number: card.number)
    end
end
