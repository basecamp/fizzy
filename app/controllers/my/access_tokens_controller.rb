class My::AccessTokensController < ApplicationController
  def index
    @access_tokens = my_access_tokens.order(created_at: :desc)
  end

  def show
    @access_token = my_access_tokens.find(verifier.verify(params[:id]))
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to my_access_tokens_path, alert: "Token is no longer visible"
  end

  def new
    @access_token = my_access_tokens.new
  end

  def create
    access_token = my_access_tokens.create!(access_token_params)
    expiring_id = verifier.generate access_token.id, expires_in: 10.seconds

    redirect_to my_access_token_path(expiring_id)
  end

  def destroy
    my_access_tokens.find(params[:id]).destroy!
    redirect_to my_access_tokens_path
  end

  private
    def my_access_tokens
      Current.identity.access_tokens
    end

    def access_token_params
      params.expect(access_token: %i[ description permission ])
    end

    def verifier
      Rails.application.message_verifier(:access_tokens)
    end
end
