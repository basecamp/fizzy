module Card::Watchable
  extend ActiveSupport::Concern

  included do
    has_many :watches, dependent: :destroy
    has_many :watchers, -> { merge(Watch.watching) }, through: :watches, source: :user

    after_create -> { watch_by creator }
  end

  def watched_by?(user)
    watchers_and_subscribers(include_only_watching: true).include?(user)
  end

  def watch_by(user)
    watches.where(user: user).first_or_create.update!(watching: true)
  end

  def unwatch_by(user)
    watches.where(user: user).first_or_create.update!(watching: false)
  end

  def watchers_and_subscribers(include_only_watching: false)
    involvements = include_only_watching ? [ :watching, :everything ] : :everything
    subscribers = collection.users.where(accesses: { involvement: involvements })

    User.where(id: subscribers.pluck(:id) +
      watches.watching.pluck(:user_id) - watches.not_watching.pluck(:user_id))
  end
end
