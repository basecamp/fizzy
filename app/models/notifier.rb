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
        notification = Notification.create_or_find_by(user: recipient, card: source.card) do |n|
          n.source = source
          n.creator = creator
          n.unread_count = 1
        end

        unless notification.previously_new_record?
          # Always include source_type in the update to prevent a race condition between
          # concurrent Event and Mention notifier jobs: without this, Rails' dirty tracking
          # may skip source_type when it hasn't changed from the stale in-memory value,
          # even though another job has since modified it in the database, leaving
          # source_type and source_id mismatched.
          notification.source_type_will_change!
          notification.update!(source: source, creator: creator, read_at: nil, unread_count: notification.unread_count + 1)
        end

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
