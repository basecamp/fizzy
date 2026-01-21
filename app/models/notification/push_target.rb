class Notification::PushTarget
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
end
