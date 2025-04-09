class EventsController < ApplicationController
  include EventsTimeline

  def index
    update_collection_filter

    @collections = Current.user.collections.alphabetically
    @filters = Current.user.filters.all

    @events = events_for_activity_day
    @next_day = latest_event_before_activity_day&.created_at
  end
end
