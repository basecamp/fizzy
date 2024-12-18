class Sessions::RelaysController < ApplicationController
  allow_unauthenticated_access

  def show
  end

  def update
    if user = User.active.find_by_relay_id(params[:id])
      start_new_session_for user
      redirect_to after_authentication_url
    else
      head :bad_request
    end
  end
end
