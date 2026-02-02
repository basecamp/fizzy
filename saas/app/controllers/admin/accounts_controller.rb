class Admin::AccountsController < AdminController
  include Admin::AccountScoped

  layout "public"

  before_action :set_account, only: %i[ edit update ]

  def index
  end

  def edit
  end

  def update
    @account.override_limits(**overridden_limits_params.to_h.symbolize_keys)
    redirect_to saas.edit_admin_account_path(@account.external_account_id), notice: "Account limits updated"
  end

  private
    def set_account
      @account = Account.find_by!(external_account_id: params[:id])
    end

    def overridden_limits_params
      params.expect(account: [ :card_count, :bytes_used ])
    end
end
