class Users::AccessTokensController < ApplicationController
  before_action :set_user
  before_action :set_access_token, except: %i[ index new create ]

  def index
    set_page_and_extract_portion_from @user.identity.access_tokens.order(created_at: :desc)
  end

  def new
    @access_token = @user.identity.access_tokens.new
  end

  def create
    @access_token = @user.identity.access_tokens.create!(access_token_params)
    redirect_to user_access_tokens_path(@user)
  end

  def destroy
    @access_token.destroy!
    redirect_to user_access_tokens_path(@user)
  end

  private
    def set_user
      @user = Current.account.users.active.find(params[:user_id])
    end

    def set_access_token
      @access_token = @user.identity.access_tokens.find(params[:id])
    end

    def access_token_params
      params.expect(access_token: [ :description, :permission ])
    end
end
