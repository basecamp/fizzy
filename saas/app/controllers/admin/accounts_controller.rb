class Admin::AccountsController < AdminController
  include Admin::AccountScoped

  layout "public"

  before_action :set_account, only: %i[ edit update ]

  def index
  end

  def edit
  end

  def update
    @account.override_limits(card_count: overridden_card_count_param)
    redirect_to saas.edit_admin_account_path(@account.external_account_id), notice: "Account limits updated"
  end

  private
    def set_account
      @account = Account.find_by!(external_account_id: params[:id])
    end

    def overridden_card_count_param
      params[:account][:overridden_card_count].to_i
    end
end
