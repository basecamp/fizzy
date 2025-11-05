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

  def cache_key
    ActiveSupport::Cache.expand_cache_key [ user, filter, day.to_date, events ], "day-timeline"
  end

  private
    TIMELINEABLE_ACTIONS = %w[
      card_assigned
      card_unassigned
      card_published
      card_closed
      card_reopened
      card_collection_changed
      card_board_changed
      card_postponed
      card_triaged
      card_sent_back_to_triage
      comment_created
    ]

    def filtered_events
      @filtered_events ||= begin
        events = timelineable_events
        events = events.where(creator_id: filter.creators.ids) if filter.creators.present?
        events
      end
    end

    def timelineable_events
      Event
        .where(board: boards)
        .where(action: TIMELINEABLE_ACTIONS)
    end

    def boards
      filter.boards.presence || user.boards
    end

    def latest_event_before
      filtered_events.where(created_at: ...day.beginning_of_day).chronologically.last
    end

    def window
      day.all_day
    end
end
