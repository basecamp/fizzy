# rbs_inline: enabled

module Card::Closeable
  extend ActiveSupport::Concern

  # @type self: singleton(Card) & singleton(Card::Closeable)

  included do
    has_one :closure, dependent: :destroy

    scope :closed, -> { joins(:closure) }
    scope :open, -> { where.missing(:closure) }

    scope :recently_closed_first, -> { closed.order("closures.created_at": :desc) }
    scope :closed_at_window, ->(window) { closed.where("closures.created_at": window) }
    scope :closed_by, ->(users) { closed.where("closures.user_id": Array(users)) }
  end

  #: -> bool
  def closed?
    # @type self: Card & Card::Closeable
    closure.present?
  end

  #: -> bool
  def open?
    !closed?
  end

  #: -> User?
  def closed_by
    # @type self: Card & Card::Closeable
    closure&.user
  end

  #: -> ActiveSupport::TimeWithZone?
  def closed_at
    # @type self: Card & Card::Closeable
    closure&.created_at
  end

  #: (?user: User) -> void
  def close(user: Current.user)
    # @type self: Card & Card::Closeable

    unless closed?
      transaction do
        create_closure! user: user
        track_event :closed, creator: user
      end
    end
  end

  #: (?user: User) -> void
  def reopen(user: Current.user)
    # @type self: Card & Card::Closeable

    if closed?
      transaction do
        closure&.destroy
        track_event :reopened, creator: user
      end
    end
  end
end
