class TransferTokensController < ApplicationController
  before_action -> { head :not_found if SingleSignOn.configured? }

  def create
    Current.identity.regenerate_transfer_token
    redirect_to user_path(Current.user)
  end
end
