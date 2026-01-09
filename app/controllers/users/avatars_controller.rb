class Users::AvatarsController < ApplicationController
  allow_unauthenticated_access only: :show

  before_action :set_user
  before_action :ensure_permission_to_administer_user, only: :destroy

  def show
    if @user.system?
      redirect_to view_context.image_path("system_user.png")
    elsif @user.avatar.attached?
      redirect_to rails_blob_path(@user.avatar_thumbnail, disposition: "inline")
    elsif stale? @user, cache_control: cache_control
      render_initials
    end
  end

  def destroy
    @user.avatar.destroy
    redirect_to @user
  end

  private
    def set_user
      @user = Current.account.users.find(params[:user_id])
    end

    def ensure_permission_to_administer_user
      head :forbidden unless Current.user.can_change?(@user)
    end

    def cache_control
      if @user == Current.user
        {}
      else
        { max_age: 30.minutes, stale_while_revalidate: 1.week }
      end
    end

    def render_initials
      render formats: :svg
    end
end
