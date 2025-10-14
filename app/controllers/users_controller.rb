class UsersController < ApplicationController
  require_unauthenticated_access only: %i[ new create ]

  include FilterScoped

  before_action :set_user, only: %i[ show edit update destroy ]
  before_action :ensure_join_code_is_valid, only: %i[ new create ]
  before_action :ensure_permission_to_change_user, only:  %i[ update destroy ]
  before_action :set_filter, only: %i[ edit show ]
  before_action :set_user_filtering, only: %i[ edit show]

  def new
    @user = User.new
  end

  def create
    user = User.create!(user_params)
    start_new_session_for user
    redirect_to root_path
  end

  def edit
  end

  def show
    @filter = Current.user.filters.new(creator_ids: [ @user.id ])
    @day_timeline = Current.user.timeline_for(day_param, filter: @filter)
  end

  def update
    @user.update! user_params
    redirect_to @user
  end

  def destroy
    @user.deactivate
    redirect_to users_path
  end

  private
    def ensure_join_code_is_valid
      head :forbidden unless Account.sole.join_code == params[:join_code]
    end

    def set_user
      @user = User.active.find(params[:id])
    end

    def ensure_permission_to_change_user
      head :forbidden unless Current.user.can_change?(@user)
    end

    def day_param
      if params[:day].present?
        Time.zone.parse(params[:day])
      else
        Time.current
      end
    end

    def user_params
      params.expect(user: [ :name, :email_address, :password, :avatar ])
    end
end
