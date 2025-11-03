class Users::AvatarsController < ApplicationController
  include ActiveStorage::Streaming

  allow_unauthenticated_access only: :show

  before_action :set_user
  before_action :ensure_permission_to_administer_user, only: :destroy

  def show
    if stale? @user, cache_control: { max_age: (30.minutes unless Current.user == @user), stale_while_revalidate: 1.week }.compact
      render_avatar_or_initials
    end
  end

  def destroy
    @user.avatar.destroy
    redirect_to @user
  end

  private
    def set_user
      @user = User.find(params[:user_id])
    end

    def ensure_permission_to_administer_user
      head :forbidden unless Current.user.admin? || Current.user == @user
    end

    def render_avatar_or_initials
      if @user.avatar.attached?
        send_blob_stream @user.avatar
      else
        render_initials
      end
    end

    def render_initials
      render formats: :svg
    end
end
