class User::DayTimeline::Column
  include ActionView::Helpers::TagHelper, ActionView::Helpers::OutputSafetyHelper, TimeHelper

  attr_reader :index, :id, :base_title, :day_timeline, :events

  def initialize(day_timeline, id, base_title, index, events)
    @id = id
    @day_timeline = day_timeline
    @base_title = base_title
    @index = index
    @events = events
  end

  def title
    date_tag = local_datetime_tag(day_timeline.day, style: :agoorweekday)
    parts = [ base_title, date_tag ]
    parts << tag.span("(#{full_events_count})", class: "font-weight-normal") if full_events_count > 0
    safe_join(parts, " ")
  end

  def events_by_hour
    limited_events.group_by { it.created_at.hour }
  end

  def has_more_events?
    limited_events.count < full_events_count
  end

  def hidden_events_count
    full_events_count - limited_events.count
  end

  def to_param
    id
  end

  private
    def limited_events
      @limited_events ||= events.limit(100).load
    end

    def full_events_count
      @full_events_count ||= events.count
    end
end
