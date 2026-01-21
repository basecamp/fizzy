class Notification::PushTarget::Web < Notification::PushTarget
  def self.push_later(notification)
    Notification::WebPushJob.perform_later(notification)
  end

  private
    def should_push?
      super && subscriptions.any?
    end

    def perform_push
      Rails.configuration.x.web_push_pool.queue(notification.payload.to_h, subscriptions)
    end

    def subscriptions
      @subscriptions ||= notification.user.push_subscriptions
    end
end
