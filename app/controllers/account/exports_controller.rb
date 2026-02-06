class Account::ExportsController < ApplicationController
  before_action :ensure_admin_or_owner
  before_action :ensure_export_limit_not_exceeded, only: :create
  before_action :set_export, only: :show

  CURRENT_EXPORT_LIMIT = 10

  def show
  end

  def create
    Current.account.exports.create!(user: Current.user).build_later
    redirect_to account_settings_path, notice: "Export started. You'll receive an email when it's ready."
  end

  private
    def ensure_admin_or_owner
      head :forbidden unless Current.user.admin? || Current.user.owner?
    end

    def ensure_export_limit_not_exceeded
      head :too_many_requests if Current.account.exports.current.count >= CURRENT_EXPORT_LIMIT
    end

    def set_export
      @export = Current.account.exports.completed.find_by(id: params[:id], user: Current.user)
    end
end
