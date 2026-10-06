class TransferTokensController < ApplicationController
  disallow_oauth_grants

  def create
    Current.identity.regenerate_transfer_token
    redirect_to user_path(Current.user)
  end
end
