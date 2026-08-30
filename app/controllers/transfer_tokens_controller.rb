class TransferTokensController < ApplicationController
  def create
    Current.identity.regenerate_transfer_token
    redirect_to user_path(Current.user)
  end
end
