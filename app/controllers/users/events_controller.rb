class Users::EventsController < ApplicationController
  include FilterScoped

  before_action :set_user, :set_filter, :set_user_filtering

  def show
    if day_param
      @filter = Current.user.filters.new(creator_ids: [ @user.id ])
      @day_timeline = Current.user.timeline_for(day_param, filter: @filter)

      fresh_when @day_timeline
    else
      head :not_found
    end
  end

  private
    def set_user
      @user = Current.account.users.active.find(params[:user_id])
    end

    def day_param
      @day_param ||= if params[:day].present?
        Time.zone.parse(params[:day])
      else
        Time.current
      end
    rescue ArgumentError, TypeError
      nil
    end
end
