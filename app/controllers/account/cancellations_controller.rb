class Account::CancellationsController < ApplicationController
  before_action :ensure_owner

  def create
    Current.account.cancel
    redirect_to session_menu_path(script_name: nil), notice: "Account deleted"
  end

  private
    def ensure_owner
      head :forbidden unless Current.user.owner?
    end
end
