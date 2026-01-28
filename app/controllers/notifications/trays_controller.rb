class Notifications::TraysController < ApplicationController
  MAX_ENTRIES_LIMIT = 100

  def show
    @notifications = unread_notifications
    if include_unread?
      @notifications += read_notifications
    end

    # Invalidate on the whole set instead of the unread set since the max updated at in the unread set
    # can stay the same when reading old notifications.
    fresh_when Current.user.notifications
  end

  private
    def unread_notifications
      Current.user.notifications.unread.preloaded.ordered.limit(MAX_ENTRIES_LIMIT)
    end

    def read_notifications
      Current.user.notifications.read.preloaded.ordered.limit(MAX_ENTRIES_LIMIT)
    end

    def include_unread?
      ActiveModel::Type::Boolean.new.cast(params[:include_unread])
    end
end
