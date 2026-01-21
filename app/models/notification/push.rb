class Notification::Push
  include ExcerptHelper

  attr_reader :notification

  delegate :card, to: :notification

  def initialize(notification)
    @notification = notification
  end

  def push
    return unless should_push?

    perform_push
  end

  private
    def should_push?
      notification.pushable?
    end

    def perform_push
      raise NotImplementedError
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

      base_payload = {
        title: card_notification_title(card),
        url: card_url(card)
      }

      case event.action
      when "comment_created"
        base_payload.merge(
          title: "RE: #{base_payload[:title]}",
          body: comment_notification_body(event),
          url: card_url_with_comment_anchor(event.eventable)
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
          body: card.closure ? "Moved to Done by #{event.creator.name}" : "Closed by #{event.creator.name}"
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

      {
        title: "#{mention.mentioner.first_name} mentioned you",
        body: format_excerpt(mention.source.mentionable_content, length: 200),
        url: card_url(card)
      }
    end

    def build_default_payload
      {
        title: "New notification",
        body: "You have a new notification",
        url: notifications_url
      }
    end

    def card_notification_title(card)
      card.title.presence || "Card #{card.number}"
    end

    def comment_notification_body(event)
      format_excerpt(event.eventable.body, length: 200)
    end

    def card_url(card)
      Rails.application.routes.url_helpers.card_url(card, **url_options)
    end

    def notifications_url
      Rails.application.routes.url_helpers.notifications_url(**url_options)
    end

    def card_url_with_comment_anchor(comment)
      Rails.application.routes.url_helpers.card_url(
        comment.card,
        anchor: ActionView::RecordIdentifier.dom_id(comment),
        **url_options
      )
    end

    def url_options
      base_options = Rails.application.routes.default_url_options.presence ||
        Rails.application.config.action_mailer.default_url_options ||
        {}
      base_options.merge(script_name: notification.account.slug)
    end
end
