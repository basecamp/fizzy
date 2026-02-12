class Notifier
  attr_reader :source

  class << self
    def for(source)
      case source
      when Event
        "Notifier::#{source.eventable.class}EventNotifier".safe_constantize&.new(source)
      when Mention
        MentionNotifier.new(source)
      end
    end
  end

  def notify
    if should_notify?
      # Processing recipients in order avoids deadlocks if notifications overlap.
      recipients.sort_by(&:id).map do |recipient|
        notification = Notification.find_or_initialize_by(user: recipient, card: source.card)
        notification.source = source
        notification.creator = creator
        notification.read_at = nil
        notification.unread_count = (notification.unread_count || 0) + 1
        notification.save!
        notification
      end
    end
  end

  private
    def initialize(source)
      @source = source
    end

    def should_notify?
      !creator.system?
    end
end
