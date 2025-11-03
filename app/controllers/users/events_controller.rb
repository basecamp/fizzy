class Users::EventsController < ApplicationController
  include FilterScoped

  before_action :set_user, :set_filter, :set_user_filtering

  def show
    @filter = Current.user.filters.new(creator_ids: [ @user.id ])
    @day_timeline = Current.user.timeline_for(day_param, filter: @filter)

    fresh_when @day_timeline
  end

  private
    def set_user
      @user = User.active.find(params[:user_id])
    end

    def day_param
      if params[:day].present?
        Time.zone.parse(params[:day])
      else
        Time.current
      end
    end
end
