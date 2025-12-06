class Users::AvatarsController < ApplicationController
  include ActiveStorage::Streaming

  allow_unauthenticated_access only: :show

  before_action :set_user
  before_action :ensure_permission_to_administer_user, only: :destroy

  def show
    expires_in 30.minutes, public: true, stale_while_revalidate: 1.week

    if @user.system?
      redirect_to view_context.image_path("system_user.png")
    elsif @user.avatar.attached?
      redirect_to rails_blob_url(@user.avatar_thumbnail, disposition: "inline")
    else
      render_initials
    end
  end

  def destroy
    @user.avatar.destroy
    @user.touch
    redirect_to @user
  end

  private
    def set_user
      @user = Current.account.users.find(params[:user_id])
    end

    def ensure_permission_to_administer_user
      head :forbidden unless Current.user.can_change?(@user)
    end

    def render_initials
      render formats: :svg
    end
end
