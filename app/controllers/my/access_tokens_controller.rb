class My::AccessTokensController < ApplicationController
  def index
    @access_tokens = Current.identity.access_tokens.order(created_at: :desc)
  end

  def new
    @access_token = Current.identity.access_tokens.new
  end

  def create
    @access_token = Current.identity.access_tokens.create!(access_token_params)
    redirect_to my_access_tokens_path
  end

  def destroy
    Current.identity.access_tokens.find(params[:id]).destroy!
    redirect_to my_access_tokens_path
  end

  private
    def access_token_params
      params.expect(access_token: [ :description, :permission ])
    end
end
