class EventsController < ApplicationController
  include DayTimelinesScoped

  def index
    fresh_when @day_timeline
  end
end
