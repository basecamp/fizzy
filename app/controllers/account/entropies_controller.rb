class Account::EntropiesController < ApplicationController
  before_action :ensure_admin

  def update
    Current.account.entropy.update!(entropy_params)
    redirect_to account_settings_path, notice: I18n.t("account.updated")
  end

  private
    def entropy_params
      params.expect(entropy: [ :auto_postpone_period ])
    end
end
