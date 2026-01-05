class Account::CancellationsController < ApplicationController
  before_action :ensure_owner

  def create
    Current.account.cancel
    redirect_to session_menu_url, notice: "Your account is scheduled for deletion."
  end

  private
    def ensure_owner
      head :forbidden unless Current.user.owner?
    end
end
