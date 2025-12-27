class Admin::AccountSearchesController < AdminController
  def create
    redirect_to saas.edit_admin_account_path(params[:q])
  end
end
