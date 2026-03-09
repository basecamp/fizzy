class Account::ExportsController < ApplicationController
  before_action :ensure_admin_or_owner
  before_action :ensure_export_limit_not_exceeded, only: :create
  before_action :set_export, only: :show

  CURRENT_EXPORT_LIMIT = 10

  def show
    respond_to do |format|
      format.html
      format.json { @export ? render(:show) : head(:not_found) }
    end
  end

  def create
    @export = Current.account.exports.create!(user: Current.user)
    @export.build_later

    respond_to do |format|
      format.html { redirect_to account_settings_path, notice: "Export started. You'll receive an email when it's ready." }
      format.json { render :show, status: :created }
    end
  end

  private
    def ensure_admin_or_owner
      head :forbidden unless Current.user.admin? || Current.user.owner?
    end

    def ensure_export_limit_not_exceeded
      head :too_many_requests if Current.account.exports.current.count >= CURRENT_EXPORT_LIMIT
    end

    def set_export
      scope = request.format.json? ? Current.account.exports : Current.account.exports.completed
      @export = scope.find_by(id: params[:id], user: Current.user)
    end
end
