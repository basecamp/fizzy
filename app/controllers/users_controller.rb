class UsersController < ApplicationController
  include FilterScoped

  require_access_without_a_user only: %i[ new create ]

  before_action :set_join_code, only: %i[ new create]
  before_action :ensure_join_code_is_valid, only: %i[ new create ]
  before_action :set_user, only: %i[ show edit update destroy ]
  before_action :ensure_permission_to_change_user, only: %i[ update destroy ]
  before_action :set_filter, only: %i[ edit show ]
  before_action :set_user_filtering, only: %i[ edit show]

  def new
  end

  def create
    @join_code.redeem do
      User.create!(user_params.merge(membership: Current.membership))
    end

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
    def set_join_code
      @join_code = Account::JoinCode.active.find_by(code: Current.membership.join_code)
    end

    def ensure_join_code_is_valid
      unless @join_code&.active?
        redirect_to unlink_membership_url(script_name: nil, membership_id: Current.membership.signed_id(purpose: :unlinking))
      end
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
      params.expect(user: [ :name, :avatar ])
    end
end
