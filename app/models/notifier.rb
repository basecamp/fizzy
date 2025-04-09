class Notifier
  attr_reader :event

  delegate :creator, to: :event

  class << self
    def for(event)
      "Notifier::#{event.action.classify}".safe_constantize&.new(event)
    end
  end

  def generate
    if should_notify?
      recipients.map do |recipient|
        Notification.create! user: recipient, event: event, card: card, resource: resource
      end
    end
  end

  private
    def initialize(event)
      @event = event
    end

    def should_notify?
      !event.creator.system?
    end

    def recipients
      card.watchers_and_subscribers.without(creator)
    end

    def resource
      card
    end

    def card
      event.summary.message.card
    end
end
