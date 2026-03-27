class Account::BotsController < ApplicationController
  before_action :ensure_admin
  before_action :set_bot, only: %i[ show destroy ]

  def new
  end

  def create
    bot, access_token = ActiveRecord::Base.transaction do
      identity = Identity.create!(email_address: "bot+#{SecureRandom.hex(4)}@fizzy.internal")
      bot = Current.account.users.create!(
        name: name,
        role: :bot,
        identity: identity,
        verified_at: Time.current
      )
      access_token = identity.access_tokens.create!(
        description: "Initial token",
        permission: :write
      )
      [ bot, access_token ]
    end

    respond_to do |format|
      format.html { redirect_to account_bot_path(bot, token: token_verifier.generate(access_token.id, expires_in: 30.seconds)) }
      format.json { render json: { user: { id: bot.id, name: bot.name, role: bot.role }, token: access_token.token }, status: :created }
    end
  end

  def show
    @access_tokens = @bot.identity.access_tokens.order(created_at: :desc)

    if params[:token]
      @new_access_token = Identity::AccessToken.find(token_verifier.verify(params[:token]))
    end
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    @new_access_token = nil
  end

  def destroy
    @bot.deactivate

    respond_to do |format|
      format.html { redirect_to account_settings_path, notice: "#{@bot.name} has been removed" }
      format.json { head :no_content }
    end
  end

  private
    def set_bot
      @bot = Current.account.users.where(role: :bot).find(params[:id])
    end

    def name
      params.expect(:name)
    end

    def token_verifier
      Rails.application.message_verifier(:bot_tokens)
    end
end
