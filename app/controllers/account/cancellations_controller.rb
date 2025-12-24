class Account::CancellationsController < ApplicationController
  before_action :ensure_owner

  def create
    Current.account.cancel
    redirect_to account_settings_path, notice: "Your account is scheduled for deletion."
  end

  def destroy
    Current.account.reactivate
    redirect_to account_settings_path, notice: "Account deletion has been canceled."
  end

  private
    def ensure_owner
      head :forbidden unless Current.user.owner?
    end
end
