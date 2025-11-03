module Card::Watchable
  extend ActiveSupport::Concern

  included do
    has_many :watches, dependent: :destroy
    has_many :watchers, -> { active.merge(Watch.watching) }, through: :watches, source: :user

    after_create :subscribe_creator
  end

  def watched_by?(user)
    watch_for(user)&.watching?
  end

  def watch_for(user)
    watches.find_by(user: user)
  end

  def watch_by(user)
    watches.where(user: user).first_or_create.update!(watching: true)
  end

  def unwatch_by(user)
    watches.where(user: user).first_or_create.update!(watching: false)
  end

  private
    def subscribe_creator
      # Avoid touching to not interfere with the abandon card detection system
      Card.no_touching do
        watch_by creator
      end
    end
end
