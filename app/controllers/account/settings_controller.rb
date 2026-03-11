class Account::SettingsController < ApplicationController
  wrap_parameters :account, include: %i[ name ]

  before_action :ensure_admin, only: :update
  before_action :set_account

  def show
    respond_to do |format|
      format.html { @users = @account.users.active.alphabetically.includes(:identity) }
      format.json
    end
  end

  def update
    @account.update!(account_params)

    respond_to do |format|
      format.html { redirect_to account_settings_path }
      format.json { head :no_content }
    end
  end

  private
    def set_account
      @account = Current.account
    end

    def account_params
      params.expect account: %i[ name ]
    end
end
