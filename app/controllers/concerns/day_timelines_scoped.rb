# rbs_inline: enabled

module DayTimelinesScoped
  extend ActiveSupport::Concern

  included do
    include FilterScoped

    before_action :set_day_timeline
  end

  private
    def set_day_timeline
      @day_timeline = Current.user.timeline_for(day, filter: @filter)
    end

    def day
      if params[:day].present?
        Time.zone.parse(params[:day])
      else
        Time.current
      end
    rescue ArgumentError
      head :not_found
    end
end
