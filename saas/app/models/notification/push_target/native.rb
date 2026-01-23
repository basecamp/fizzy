class Notification::PushTarget::Native < Notification::PushTarget
  def process
    if devices.any?
      native_notification.deliver_later_to(devices)
    end
  end

  private
    def devices
      @devices ||= notification.identity.devices
    end

    def payload
      @payload ||= notification.payload
    end

    def native_notification
      ApplicationPushNotification
        .with_apple(
          aps: {
            category: payload.category,
            "mutable-content": 1,
            "interruption-level": interruption_level
          }
        )
        .with_google(
          android: { notification: nil }
        )
        .with_data(
          title: payload.title,
          body: payload.body,
          url: payload.url,
          account_id: notification.account.external_account_id,
          avatar_url: creator_avatar_url,
          card_id: card&.id,
          card_title: card&.title,
          creator_name: notification.creator.name,
          category: payload.category
        )
        .new(
          title: payload.title,
          body: payload.body,
          badge: notification.user.notifications.unread.count,
          sound: "default",
          thread_id: card&.id,
          high_priority: payload.high_priority?
        )
    end

    def interruption_level
      payload.high_priority? ? "time-sensitive" : "active"
    end

    def creator_avatar_url
      if notification.creator.respond_to?(:avatar) && notification.creator.avatar.attached?
        Rails.application.routes.url_helpers.url_for(notification.creator.avatar)
      end
    end
end
