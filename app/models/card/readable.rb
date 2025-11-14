module Card::Readable
  extend ActiveSupport::Concern

  def read_by(user)
    notifications_for(user).tap do |notifications|
      notifications.each(&:read)
    end
  end

  def unread_by(user)
    all_notifications_for(user).tap do |notifications|
      notifications.each(&:unread)
    end
  end

  def remove_inaccessible_notifications
    User.find_each do |user|
      all_notifications_for(user).destroy_all unless accessible_to?(user)
    end
  end

  private
    def remove_inaccessible_notifications_later
      Card::RemoveInaccessibleNotificationsJob.perform_later(self)
    end

    def notifications_for(user)
      scope = user.notifications.unread
      scope.where(source: event_notification_sources)
        .or(scope.where(source: mention_notification_sources))
    end

    def all_notifications_for(user)
      scope = user.notifications
      scope.where(source: event_notification_sources)
        .or(scope.where(source: mention_notification_sources))
    end

    def event_notification_sources
      events.or(comment_creation_events)
    end

    def comment_creation_events
      Event.where(eventable: comments)
    end

    def mention_notification_sources
      mentions.or(comment_mentions)
    end

    def comment_mentions
      Mention.where(source: comments)
    end
end
