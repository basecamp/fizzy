class Account::EntropiesController < ApplicationController
  before_action :ensure_admin

  def update
    Current.account.entropy.update!(entropy_params)
    respond_to do |format|
      format.html { redirect_to account_settings_path, notice: "Account updated" }
      format.json { head :no_content }
    end
  end

  private
    def entropy_params
      params.expect(entropy: [ :auto_postpone_period ])
    end
end
