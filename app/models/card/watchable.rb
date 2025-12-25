# rbs_inline: enabled

module Card::Watchable
  extend ActiveSupport::Concern

  # @type self: singleton(Card::Concern)

  included do
    has_many :watches, dependent: :destroy
    has_many :watchers, -> { active.merge(Watch.watching) }, through: :watches, source: :user

    after_create :subscribe_creator
  end

  def watched_by?(user)
    # @type self: Card::Concern
    watch_for(user)&.watching?
  end

  def watch_for(user)
    # @type self: Card::Concern
    watches.find_by(user: user)
  end

  def watch_by(user)
    # @type self: Card::Concern
    watches.where(user: user).first_or_create.update!(watching: true)
  end

  def unwatch_by(user)
    # @type self: Card::Concern
    watches.where(user: user).first_or_create.update!(watching: false)
  end

  private
    def subscribe_creator
      # @type self: Card::Concern
      # Avoid touching to not interfere with the abandon card detection system
      Card.no_touching do
        watch_by creator
      end
    end
end
