class Notifications::TraysController < ApplicationController
  def show
    @notifications = Current.user.notifications.unread.preloaded.ordered.limit(100)

    # Invalidate on the whole set instead of the unread set since the max updated at in the unread set
    # can stay the same when reading old notifications.
    fresh_when Current.user.notifications
  end
end
