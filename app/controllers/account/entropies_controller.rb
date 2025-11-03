class Account::EntropiesController < ApplicationController
  def update
    Account.sole.entropy.update!(entropy_params)
    redirect_to account_settings_path, notice: "Account updated"
  end

  private
    def entropy_params
      params.expect(entropy: [ :auto_postpone_period ])
    end
end
