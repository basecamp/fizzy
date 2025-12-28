# rbs_inline: enabled

module Card::Eventable
  extend ActiveSupport::Concern

  include ::Eventable

  included do
    # @type self: singleton(Card)

    before_create { self.last_active_at = Time.current }

    after_save :track_title_change, if: :saved_change_to_title?
  end

  def event_was_created(event)
    # @type self: Card
    transaction do
      create_system_comment_for(event)
      touch_last_active_at
    end
  end

  def touch_last_active_at
    # @type self: Card
    # Not using touch so that we can detect attribute change on callbacks
    update!(last_active_at: Time.current)
  end

  private
    def should_track_event?
      # @type self: Card
      published?
    end

    def track_title_change
      # @type self: Card
      if title_before_last_save.present?
        track_event "title_changed", particulars: { old_title: title_before_last_save, new_title: title }
      end
    end

    def create_system_comment_for(event)
      SystemCommenter.new(self, event).comment
    end
end
