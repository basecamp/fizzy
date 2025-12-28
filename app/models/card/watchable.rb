# rbs_inline: enabled

module Card::Watchable
  extend ActiveSupport::Concern

  # @type self: singleton(Card) & singleton(Card::Watchable)

  included do
    has_many :watches, dependent: :destroy
    has_many :watchers, -> { active.merge(Watch.watching) }, through: :watches, source: :user

    after_create :subscribe_creator
  end

  #: (User) -> bool?
  def watched_by?(user)
    # @type self: Card & Card::Watchable
    watch_for(user)&.watching?
  end

  #: (User) -> Watch?
  def watch_for(user)
    # @type self: Card & Card::Watchable
    watches.find_by(user: user)
  end

  #: (User) -> void
  def watch_by(user)
    # @type self: Card & Card::Watchable
    watches.where(user: user).first_or_create.update!(watching: true)
  end


  #: (User) -> void
  def unwatch_by(user)
    # @type self: Card & Card::Watchable
    watches.where(user: user).first_or_create.update!(watching: false)
  end

  private
    #: -> void
    def subscribe_creator
      # @type self: Card & Card::Watchable
      # Avoid touching to not interfere with the abandon card detection system
      Card.no_touching do
        watch_by creator
      end
    end
end
