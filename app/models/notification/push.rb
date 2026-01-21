class Notification::Push
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
        Notification::EventPayload.new(notification).to_h
      when "Mention"
        Notification::MentionPayload.new(notification).to_h
      else
        Notification::DefaultPayload.new(notification).to_h
      end
    end
end
