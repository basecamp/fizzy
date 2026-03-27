class Account::EntropiesController < ApplicationController
  wrap_parameters :entropy, include: [ :auto_postpone_period_in_days ]

  before_action :ensure_admin

  def update
    @account = Current.account
    @account.entropy.update!(entropy_params)

    respond_to do |format|
      format.html { redirect_to account_settings_path, notice: "Account updated" }
      format.json { render "account/settings/show", status: :ok }
    end
  rescue ActiveRecord::RecordInvalid
    head :unprocessable_entity
  end

  private
    def entropy_params
      params.expect(entropy: [ :auto_postpone_period_in_days ])
    end
end
