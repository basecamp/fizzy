class Users::RolesController < ApplicationController
  before_action :set_user
  before_action :ensure_permission_to_administer_user

  def update
    @user.update!(role_params)
    redirect_to users_path
  end

  private
    def set_user
      @user = User.active.find(params[:user_id])
    end

    def ensure_permission_to_administer_user
      head :forbidden unless Current.user.can_administer?(@user)
    end

    def role_params
      { role: params.require(:user)[:role].presence_in(%w[ member admin ]) || "member" }
    end
end
