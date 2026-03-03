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
          base_url: payload.base_url,
          account_id: notification.account.id,
          account_slug: notification.account.slug,
          avatar_url: payload.avatar_url,
          card_id: card&.id,
          card_title: card&.title,
          creator_id: notification.creator.id,
          creator_name: notification.creator.name,
          creator_familiar_name: notification.creator.familiar_name,
          creator_initials: notification.creator.initials,
          creator_avatar_color: notification.creator.avatar_background_color,
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
end
