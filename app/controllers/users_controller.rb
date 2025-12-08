class UsersController < ApplicationController
  before_action :set_user
  before_action :ensure_permission_to_change_user, only: %i[ update destroy ]

  def show
  end

  def edit
  end

  def update
    if @user.update(user_params)
      redirect_to @user
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @user.deactivate
    redirect_to users_path
  end

  private
    def set_user
      @user = Current.account.users.active.find(params[:id])
    end

    def ensure_permission_to_change_user
      head :forbidden unless Current.user.can_change?(@user)
    end

    def user_params
      params.expect(user: [ :name, :avatar ])
    end
end
