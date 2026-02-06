module Admin::AccountScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_account
  end

  private
    def set_account
      @account = Account.find_by!(external_account_id: params[:account_id] || params[:id])
    end
end
