class NotificationPusher
  include Rails.application.routes.url_helpers
  include ExcerptHelper

  attr_reader :notification

  def initialize(notification)
    @notification = notification
  end

  def push
    return unless should_push?

    build_payload.tap do |payload|
      push_to_user(payload)
    end
  end

  private
    def should_push?
      notification.user.push_subscriptions.any? &&
        !notification.creator.system? &&
        notification.user.active? &&
        notification.account.active?
    end

    def build_payload
      case notification.source_type
      when "Event"
        build_event_payload
      when "Mention"
        build_mention_payload
      else
        build_default_payload
      end
    end

    def build_event_payload
      event = notification.source
      card = event.card

      base_payload = {
        title: card_notification_title(card),
        path: card_path(card)
      }

      case event.action
      when "comment_created"
        base_payload.merge(
          title: I18n.t("notifications.re_prefix", title: base_payload[:title]),
          body: comment_notification_body(event),
          path: card_path_with_comment_anchor(event.eventable)
        )
      when "card_assigned"
        base_payload.merge(
          body: I18n.t("notifications.assigned_to_you_by", creator: event.creator.name)
        )
      when "card_published"
        base_payload.merge(
          body: I18n.t("notifications.added_by", creator: event.creator.name)
        )
      when "card_closed"
        base_payload.merge(
          body: card.closure ? I18n.t("notifications.moved_to_done_by", creator: event.creator.name) : I18n.t("notifications.closed_by", creator: event.creator.name)
        )
      when "card_reopened"
        base_payload.merge(
          body: I18n.t("notifications.reopened_by", creator: event.creator.name)
        )
      else
        base_payload.merge(
          body: event.creator.name
        )
      end
    end

    def build_mention_payload
      mention = notification.source
      card = mention.card

      {
        title: "#{mention.mentioner.first_name} mentioned you",
        body: format_excerpt(mention.source.mentionable_content, length: 200),
        path: card_path(card)
      }
    end

    def build_default_payload
      {
        title: I18n.t("notifications.new_notification_title"),
        body: I18n.t("notifications.new_notification_body"),
        path: notifications_path(script_name: notification.account.slug)
      }
    end

    def push_to_user(payload)
      subscriptions = notification.user.push_subscriptions
      enqueue_payload_for_delivery(payload, subscriptions)
    end

    def enqueue_payload_for_delivery(payload, subscriptions)
      Rails.configuration.x.web_push_pool.queue(payload, subscriptions)
    end

    def card_notification_title(card)
      card.title.presence || I18n.t("notifications.card_title", number: card.number)
    end

    def comment_notification_body(event)
      format_excerpt(event.eventable.body, length: 200)
    end

    def card_path(card)
      Rails.application.routes.url_helpers.card_path(card, script_name: notification.account.slug)
    end

    def card_path_with_comment_anchor(comment)
      Rails.application.routes.url_helpers.card_path(
        comment.card,
        anchor: ActionView::RecordIdentifier.dom_id(comment),
        script_name: notification.account.slug
      )
    end
end
