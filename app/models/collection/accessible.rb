module Collection::Accessible
  extend ActiveSupport::Concern

  included do
    has_many :accesses, dependent: :delete_all do
      def revise(granted: [], revoked: [])
        transaction do
          grant_to granted
          revoke_from revoked
        end
      end

      def grant_to(users)
        Access.insert_all Array(users).collect { |user| { collection_id: proxy_association.owner.id, user_id: user.id } }
      end

      def revoke_from(users)
        destroy_by user: users unless proxy_association.owner.all_access?
      end
    end

    has_many :users, through: :accesses
    has_many :access_only_users, -> { merge(Access.access_only) }, through: :accesses, source: :user

    scope :all_access, -> { where(all_access: true) }

    after_create :grant_access_to_creator
    after_save_commit :grant_access_to_everyone
  end

  def accessed_by(user)
    access_for(user).accessed
  end

  def access_for(user)
    accesses.find_by(user: user)
  end

  def accessible_to?(user)
    access_for(user).present?
  end

  def clean_inaccessible_data_for(user)
    return if accessible_to?(user)

    mentions_for_user(user).destroy_all
    notifications_for_user(user).destroy_all
  end

  def watchers
    users.without(User.system).where(accesses: { involvement: :watching })
  end

  private
    def grant_access_to_creator
      accesses.create(user: creator, involvement: :watching)
    end

    def grant_access_to_everyone
      accesses.grant_to(User.all) if all_access_previously_changed?(to: true)
    end

    def mentions_for_user(user)
      # Query handles 2 paths:
      #
      # 1. Mention->Card
      # 2. Mention->Comment->Card
      user.mentions
        .joins("LEFT JOIN cards ON mentions.source_id = cards.id AND mentions.source_type = 'Card'")
        .joins("LEFT JOIN comments ON mentions.source_id = comments.id AND mentions.source_type = 'Comment'")
        .joins("LEFT JOIN cards AS comment_cards ON comments.card_id = comment_cards.id")
        .where("(mentions.source_type = 'Card' AND cards.collection_id = ?) OR (mentions.source_type = 'Comment' AND comment_cards.collection_id = ?)", id, id)
    end

    def notifications_for_user(user)
      # Query handles 2 paths:
      #
      # 1. Notification->Event->Card
      # 2. Notification->Event->Comment->Card
      #
      # Notification->Event->Mention->Card and Notification->Event->Mention->Comment->Card are
      # handled by destroying mentions_for_user.
      user.notifications
        .joins("LEFT JOIN events ON notifications.source_id = events.id AND notifications.source_type = 'Event'")
        .joins("LEFT JOIN cards AS event_cards ON events.eventable_id = event_cards.id AND events.eventable_type = 'Card'")
        .joins("LEFT JOIN comments AS event_comments ON events.eventable_id = event_comments.id AND events.eventable_type = 'Comment'")
        .joins("LEFT JOIN cards AS event_comment_cards ON event_comments.card_id = event_comment_cards.id")
        .where("(notifications.source_type = 'Event' AND events.eventable_type = 'Card' AND event_cards.collection_id = ?) OR
              (notifications.source_type = 'Event' AND events.eventable_type = 'Comment' AND event_comment_cards.collection_id = ?)",
               id, id)
    end
end
