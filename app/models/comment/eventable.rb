# rbs_inline: enabled

module Comment::Eventable
  extend ActiveSupport::Concern

  # @type self: singleton(Comment) & singleton(Comment::Eventable)

  include ::Eventable

  included do
    after_create_commit :track_creation
  end

  def event_was_created(event)
    # @type self: Comment & Comment::Eventable
    card.touch_last_active_at
  end

  private
    def should_track_event?
      # @type self: Comment & Comment::Eventable
      !creator.system?
    end

    def track_creation
      # @type self: Comment & Comment::Eventable
      track_event("created", board: card.board, creator: creator)
    end
end
