class Account::BotAccessTokensController < ApplicationController
  before_action :ensure_admin
  before_action :set_bot

  def new
    @access_token = bot_access_tokens.new
  end

  def create
    access_token = bot_access_tokens.create!(access_token_params)
    expiring_id = token_verifier.generate(access_token.id, expires_in: 30.seconds)

    redirect_to account_bot_path(@bot, token: expiring_id)
  end

  def destroy
    bot_access_tokens.find(params[:id]).destroy!
    redirect_to account_bot_path(@bot)
  end

  private
    def set_bot
      @bot = Current.account.users.where(role: :bot).find(params[:bot_id])
    end

    def bot_access_tokens
      @bot.identity.access_tokens
    end

    def access_token_params
      params.expect(access_token: %i[ description permission ])
    end

    def token_verifier
      Rails.application.message_verifier(:bot_tokens)
    end
end
