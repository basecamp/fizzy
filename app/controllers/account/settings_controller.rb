class Account::SettingsController < ApplicationController
  before_action :ensure_admin, only: :update
  before_action :set_account

  def show
    @users = User.active.alphabetically
  end

  def update
    @account.update!(account_params)
    redirect_to account_settings_path
  end

  private
    def set_account
      @account = Account.sole
    end

    def account_params
      params.expect account: %i[ name ]
    end
end
