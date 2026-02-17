module Card::Readable
  extend ActiveSupport::Concern

  def read_by(user)
    user.notifications.find_by(card: self)&.tap(&:read)
  end

  def unread_by(user)
    user.notifications.find_by(card: self)&.tap(&:unread)
  end

  def remove_inaccessible_notifications
    accessible_user_ids = board.accesses.pluck(:user_id)
    notification_sources.each do |sources|
      inaccessible_notifications_from(sources, accessible_user_ids).in_batches.destroy_all
    end
  end

  private
    def remove_inaccessible_notifications_later
      Card::RemoveInaccessibleNotificationsJob.perform_later(self)
    end

    def event_notification_sources
      events.or(comment_creation_events)
    end

    def comment_creation_events
      Event.where(eventable: comments)
    end

    def inaccessible_notifications_from(sources, accessible_user_ids)
      Notification.where(source: sources).where.not(user_id: accessible_user_ids)
    end

    def notification_sources
      [ events, comment_creation_events, mentions, comment_mentions ]
    end

    def mention_notification_sources
      mentions.or(comment_mentions)
    end

    def comment_mentions
      Mention.where(source: comments)
    end
end
