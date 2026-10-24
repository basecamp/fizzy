class My::AccessTokensController < ApplicationController
  wrap_parameters :access_token, include: %i[ description permission ]

  skip_before_action :require_account
  disallow_oauth_grants

  def index
    @access_tokens = my_access_tokens.order(created_at: :desc)
  end

  def new
    @access_token = my_access_tokens.new
  end

  # The raw token is shown in this response and on no page after it, so the
  # response must not be cached.
  def create
    @access_token = my_access_tokens.create!(access_token_params)
    no_store

    respond_to do |format|
      format.turbo_stream
      format.html { render :create, status: :created }

      format.json do
        render status: :created, json: \
          { id: @access_token.id, token: @access_token.raw_token, description: @access_token.description,
            permission: @access_token.permission, created_at: @access_token.created_at.utc }
      end
    end
  end

  def destroy
    my_access_tokens.find(params[:id]).revoke reason: "revoked", actor: "user"

    respond_to do |format|
      format.html { redirect_to my_access_tokens_path }
      format.json { head :no_content }
    end
  end

  private
    def my_access_tokens
      Current.identity.access_tokens.personal
    end

    def access_token_params
      params.expect(access_token: %i[ description permission ])
    end
end
