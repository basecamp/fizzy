class Sessions::TransfersController < ApplicationController
  require_untenanted_access
  require_unauthenticated_access

  def show
  end

  def update
    if identity = Identity.find_by_transfer_id(params[:id])
      start_new_session_for identity
      redirect_to session_menu_path(script_name: nil)
    else
      head :bad_request
    end
  end
end
