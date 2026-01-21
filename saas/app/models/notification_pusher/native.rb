module NotificationPusher::Native
  extend ActiveSupport::Concern

  def push
    return unless should_push?

    build_payload.tap do |payload|
      push_to_web(payload) if notification.user.push_subscriptions.any?
      push_to_native(payload)
    end
  end

  private
    def push_destination?
      notification.user.push_subscriptions.any? || notification.user.devices.any?
    end

    def push_to_native(payload)
      devices = notification.user.devices
      return if devices.empty?

      native_notification(payload).deliver_later_to(devices)
    end

    def native_notification(payload)
      ApplicationPushNotification
        .with_apple(
          aps: {
            category: notification_category,
            "mutable-content": 1,
            "interruption-level": interruption_level
          }
        )
        .with_google(
          android: { notification: nil }
        )
        .with_data(
          title: payload[:title],
          body: payload[:body],
          path: payload[:path],
          account_id: notification.account.external_account_id,
          avatar_url: creator_avatar_url,
          card_id: card&.id,
          card_title: card&.title,
          creator_name: notification.creator.name,
          category: notification_category
        )
        .new(
          title: payload[:title],
          body: payload[:body],
          badge: notification.user.notifications.unread.count,
          sound: "default",
          thread_id: card&.id,
          high_priority: assignment_notification?
        )
    end

    def notification_category
      case notification.source
      when Event
        case notification.source.action
        when "card_assigned" then "assignment"
        when "comment_created" then "comment"
        else "card"
        end
      when Mention
        "mention"
      else
        "default"
      end
    end

    def interruption_level
      assignment_notification? ? "time-sensitive" : "active"
    end

    def assignment_notification?
      notification.source.is_a?(Event) && notification.source.action == "card_assigned"
    end

    def creator_avatar_url
      return unless notification.creator.respond_to?(:avatar) && notification.creator.avatar.attached?
      Rails.application.routes.url_helpers.url_for(notification.creator.avatar)
    end

    def card
      @card ||= notification.card
    end
end
