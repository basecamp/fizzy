# rbs_inline: enabled

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

  #: -> Array[ApplicationRecord]?
  def notify
    if should_notify?
      # Processing recipients in order avoids deadlocks if notifications overlap.
      recipients.sort_by(&:id).map do |recipient|
        Notification.create! user: recipient, source: source, creator: creator
      end
    end
  end

  private
    def initialize(source)
      @source = source
    end

    #: -> bool
    def should_notify?
      !creator.system?
    end
end
