class UsersController < ApplicationController
  wrap_parameters :user, include: %i[ name avatar ]

  before_action :set_user, except: %i[ index ]
  before_action :ensure_permission_to_change_user, only: %i[ update destroy ]
  before_action :ensure_user_is_not_sole_owner, only: %i[ destroy ]

  def index
    set_page_and_extract_portion_from Current.account.users.active.alphabetically.includes(:identity)
  end

  def show
  end

  def edit
  end

  def update
    if @user.update(user_params)
      respond_to do |format|
        format.html { redirect_to @user }
        format.json { render :show }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @user.deactivate

    respond_to do |format|
      format.html { redirect_to account_settings_path }
      format.json { head :no_content }
    end
  end

  private
    def set_user
      @user = Current.account.users.active.find(params[:id])
    end

    def ensure_permission_to_change_user
      head :forbidden unless Current.user.can_change?(@user)
    end

    def ensure_user_is_not_sole_owner
      if @user.sole_owner?
        respond_to do |format|
          format.html { redirect_to account_settings_path, alert: "You're the only owner of this account and can't be removed" }
          format.json { head :unprocessable_entity }
        end
      end
    end

    def user_params
      params.expect(user: [ :name, :avatar ])
    end
end
