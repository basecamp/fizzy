module Bubble::Eventable
  extend ActiveSupport::Concern

  included do
    has_many :events, dependent: :destroy
    before_create { self.last_active_at = Time.current }
  end

  def touch_last_active_at
    touch :last_active_at
  end

  private
    def track_event(action, creator: Current.user, **particulars)
      if published?
        event = find_or_capture_event_summary.events.create! action: action, creator: creator, bubble: self, particulars: particulars
        event.generate_notifications_later
      end
    end

    def find_or_capture_event_summary
      transaction do
        messages.last&.event_summary || capture(EventSummary.new).event_summary
      end
    end
end
