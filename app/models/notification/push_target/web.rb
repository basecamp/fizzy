class Notification::PushTarget::Web < Notification::PushTarget
  def process
    if subscriptions.any?
      Rails.configuration.x.web_push_pool.queue(notification.payload.to_h, subscriptions)
    end
  end

  private
    def subscriptions
      @subscriptions ||= notification.user.push_subscriptions
    end
end
