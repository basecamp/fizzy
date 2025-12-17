class Users::VerificationsController < ApplicationController
  layout "public"

  def new
  end

  def create
    Current.user.verify
    redirect_to new_users_join_path
  end
end
