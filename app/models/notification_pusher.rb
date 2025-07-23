class NotificationPusher
  include Rails.application.routes.url_helpers

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
    def account_prefix
      "/#{Account.sole.queenbee_id}"
    end

    def should_push?
      notification.user.push_subscriptions.any? &&
        !notification.creator.system? &&
        notification.user.active?
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
          title: "RE: #{base_payload[:title]}",
          body: comment_notification_body(event)
        )
      when "card_assigned"
        base_payload.merge(
          body: "Assigned to you by #{event.creator.name}"
        )
      when "card_published"
        base_payload.merge(
          body: "Added by #{event.creator.name}"
        )
      when "card_closed"
        base_payload.merge(
          body: card.closure ? "Closed as \"#{card.closure.reason}\" by #{event.creator.name}" : "Closed by #{event.creator.name}"
        )
      when "card_reopened"
        base_payload.merge(
          body: "Reopened by #{event.creator.name}"
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
        body: mention.source.mentionable_content.truncate(200),
        path: card_path(card)
      }
    end

    def build_default_payload
      {
        title: "New notification",
        body: "You have a new notification",
        path: "#{account_prefix}#{notifications_path}"
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
      card.title.presence || "Card #{card.id}"
    end

    def comment_notification_body(event)
      comment = event.eventable
      strip_tags(comment.body.to_s).truncate(200)
    end

    def strip_tags(text)
      ActionView::Base.full_sanitizer.sanitize(text)
    end

    def card_path(card)
      "#{account_prefix}#{collection_card_path(card.collection, card)}"
    end
end
