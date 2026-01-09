# rbs_inline: enabled

module Card::Readable
  extend ActiveSupport::Concern

  # @type self: singleton(Card) & singleton(Card::Readable)
  # @type instance: Card & Card::Readable

  #: (User) -> void
  def read_by(user)
    notifications_for(user).tap do |notifications|
      notifications.each(&:read)
    end
  end

  #: (User) -> void
  def unread_by(user)
    all_notifications_for(user).tap do |notifications|
      notifications.each(&:unread)
    end
  end

  #: -> void
  def remove_inaccessible_notifications
    accessible_user_ids = board.accesses.pluck(:user_id)
    notification_sources.each do |sources|
      inaccessible_notifications_from(sources, accessible_user_ids).in_batches.destroy_all
    end
  end

  private
    #: -> void
    def remove_inaccessible_notifications_later
      Card::RemoveInaccessibleNotificationsJob.perform_later(self)
    end

    #: (User) -> Notification::ActiveRecord_Relation
    def notifications_for(user)
      scope = user.notifications.unread
      scope.where(source: event_notification_sources)
        .or(scope.where(source: mention_notification_sources))
    end

    #: (User) -> Notification::ActiveRecord_Associations_CollectionProxy
    def all_notifications_for(user)
      scope = user.notifications
      scope.where(source: event_notification_sources)
        .or(scope.where(source: mention_notification_sources))
    end

    #: -> Event::ActiveRecord_Associations_CollectionProxy
    def event_notification_sources
      events.or(comment_creation_events)
    end

    #: -> Event::ActiveRecord_Relation
    def comment_creation_events
      Event.where(eventable: comments)
    end

    #: (Event::ActiveRecord_Relation, Array[Integer]) -> Notification::ActiveRecord_Relation
    def inaccessible_notifications_from(sources, accessible_user_ids)
      Notification.where(source: sources).where.not(user_id: accessible_user_ids)
    end

    def notification_sources
      [ events, comment_creation_events, mentions, comment_mentions ]
    end

    def mention_notification_sources
      mentions.or(comment_mentions)
    end

    #: -> Mention::ActiveRecord_Relation
    def comment_mentions
      Mention.where(source: comments)
    end
end
