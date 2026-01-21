class Notification::Push::Web < Notification::Push
  def self.push_later(notification)
    Notification::WebPushJob.perform_later(notification)
  end

  private
    def should_push?
      super && subscriptions.any?
    end

    def perform_push
      Rails.configuration.x.web_push_pool.queue(build_payload, subscriptions)
    end

    def subscriptions
      @subscriptions ||= notification.user.push_subscriptions
    end
end
