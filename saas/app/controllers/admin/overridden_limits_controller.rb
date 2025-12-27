class Admin::OverriddenLimitsController < AdminController
  include Admin::AccountScoped

  def destroy
    @account.reset_overridden_limits
    redirect_to saas.edit_admin_account_path(@account.external_account_id), notice: "Limits reset"
  end
end
