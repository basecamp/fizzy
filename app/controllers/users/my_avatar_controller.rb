class Users::MyAvatarController < ApplicationController
  include ActiveStorage::Streaming

  def show
    if stale? Current.user
      if Current.user.avatar.attached?
        redirect_to rails_blob_url(Current.user.avatar_thumbnail, disposition: "inline")
      else
        render_initials
      end
    end
  end

  private
    def render_initials
      render formats: :svg
    end
end
