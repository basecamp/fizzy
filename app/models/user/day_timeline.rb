class User::DayTimeline
  include Serializable

  attr_reader :user, :day, :filter

  delegate :today?, to: :day

  def initialize(user, day, filter)
    @user, @day, @filter = user, day, filter
  end

  def has_activity?
    events.any?
  end

  def events
    filtered_events.where(created_at: window).order(created_at: :desc)
  end

  def next_day
    latest_event_before&.created_at
  end

  def earliest_time
    next_day&.tomorrow&.beginning_of_day
  end

  def latest_time
    day.yesterday.beginning_of_day
  end

  def has_weekly_highlights?
    !filter.used? && first_day_with_activity_this_week? && weekly_highlights.present?
  end

  def weekly_highlights
    @weekly_highlights ||= user.weekly_highlights_for(week_starts_at)
  end

  def week_starts_at
    day.beginning_of_week(:sunday)
  end

  def week_ends_at
    week_starts_at + 1.week
  end

  def cache_key
    ActiveSupport::Cache.expand_cache_key [ user, filter, day.to_date, events, weekly_highlights ], "day-timeline"
  end

  private
    def first_day_with_activity_this_week?
      day.monday? || (earliest_time.present? && earliest_time < day.beginning_of_week(:monday))
    end

    def filtered_events
      @filtered_events ||= begin
        events = Event.where(collection: collections)
        events = events.where(creator_id: filter.creators.ids) if filter.creators.present?
        events
      end
    end

    def collections
      filter.collections.presence || user.collections
    end

    def latest_event_before
      filtered_events.where(created_at: ...day.beginning_of_day).chronologically.last
    end

    def window
      day.all_day
    end
end
