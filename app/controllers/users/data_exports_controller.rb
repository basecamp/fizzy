class Users::DataExportsController < ApplicationController
  before_action :set_user
  before_action :ensure_current_user
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
    @export = @user.data_exports.create!(account: Current.account)
    @export.build_later

    respond_to do |format|
      format.html { redirect_to @user, notice: "Export started. You'll receive an email when it's ready." }
      format.json { render :show, status: :created }
    end
  end

  private
    def set_user
      @user = Current.account.users.find(params[:user_id])
    end

    def ensure_current_user
      head :forbidden unless @user == Current.user
    end

    def ensure_export_limit_not_exceeded
      head :too_many_requests if @user.data_exports.current.count >= CURRENT_EXPORT_LIMIT
    end

    def set_export
      scope = request.format.json? ? @user.data_exports : @user.data_exports.completed
      @export = scope.find_by(id: params[:id])
    end
end
