class Notification::Push::Native < Notification::Push
  def self.push_later(notification)
    Notification::NativePushJob.perform_later(notification)
  end

  private
    def should_push?
      super && devices.any?
    end

    def perform_push
      native_notification(build_payload).deliver_later_to(devices)
    end

    def devices
      @devices ||= notification.identity.devices
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
          url: payload[:url],
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
end
