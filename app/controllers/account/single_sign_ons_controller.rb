class Account::SingleSignOnsController < ApplicationController
  wrap_parameters :account, include: %i[ single_sign_on_group ]

  before_action :ensure_single_sign_on_configured
  before_action :ensure_single_sign_on_admin

  def update
    @account = Current.account

    if @account.update(single_sign_on_params)
      respond_to do |format|
        format.html { redirect_to account_settings_path, notice: "Account updated" }
        format.json { render "account/settings/show", status: :ok }
      end
    else
      respond_to do |format|
        format.html { redirect_to account_settings_path, alert: @account.errors.full_messages.to_sentence }
        format.json { render json: { error: @account.errors.full_messages.to_sentence }, status: :unprocessable_entity }
      end
    end
  end

  private
    # Members of the admin group open every account, so a group change cannot lock them out.
    def ensure_single_sign_on_admin
      head :forbidden unless Current.session&.single_sign_on_admin?
    end

    def single_sign_on_params
      params.expect(account: %i[ single_sign_on_group ])
    end
end
