class Sessions::TransfersController < ApplicationController
  disallow_account_scope
  require_unauthenticated_access

  def show
  end

  def update
    # find_by_transfer_id consumes the token before the session is established, so a
    # failure here burns the link (fail-closed) rather than leaving a single-use token
    # redeemable. That's the safe direction for an auth credential; the person just
    # generates a fresh link.
    if identity = Identity.find_by_transfer_id(params[:id])
      start_new_session_for identity
      redirect_to session_menu_path(script_name: nil)
    else
      head :bad_request
    end
  end
end
