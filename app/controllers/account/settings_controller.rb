class Account::SettingsController < ApplicationController
  before_action :ensure_admin, only: :update
  before_action :set_account

  def show
    @users = @account.users.active.alphabetically.includes(:identity)
  end

  def update
    @account.update!(account_params)
    respond_to do |format|
      format.html { redirect_to account_settings_path }
      format.turbo_stream # Renders update.turbo_stream.erb
    end
  end

  private
    def set_account
      @account = Current.account
    end

    def account_params
      params.expect account: %i[ name signups_enabled ]
    end
end
