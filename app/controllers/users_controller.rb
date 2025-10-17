class UsersController < ApplicationController
  require_unauthenticated_access only: %i[ new create ]

  include FilterScoped

  before_action :set_user, only: %i[ show edit update destroy ]
  before_action :ensure_join_code_is_valid, only: %i[ new create ]
  before_action :ensure_permission_to_change_user, only:  %i[ update destroy ]
  before_action :set_filter, only: %i[ edit show ]
  before_action :set_user_filtering, only: %i[ edit show]

  def new
  end

  def create
    if Account::JoinCode.redeem(params[:join_code])
      User.invite(**invite_params)
      redirect_to session_magic_link_path(script_name: nil)
    else
      head :forbidden
    end
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
      head :forbidden unless Account::JoinCode.active?(params[:join_code])
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
      params.expect(user: [ :name, :email_address, :avatar ])
    end

    def invite_params
      params.expect(user: [ :name, :email_address ])
    end
end
