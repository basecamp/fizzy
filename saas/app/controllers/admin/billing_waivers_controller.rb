class Admin::BillingWaiversController < AdminController
  include Admin::AccountScoped

  def create
    @account.comp
    redirect_to saas.edit_admin_account_path(@account.external_account_id), notice: "Account comped"
  end

  def destroy
    @account.uncomp
    redirect_to saas.edit_admin_account_path(@account.external_account_id), notice: "Account uncomped"
  end
end
