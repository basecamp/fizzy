class Account::ExportsController < ApplicationController
  before_action :ensure_export_limit_not_exceeded, only: :create
  before_action :set_export, only: :show

  CURRENT_EXPORT_LIMIT = 10

  def show
    respond_to do |format|
      format.html
      format.json do
        if @export
          render json: @export.as_json(only: %i[id status created_at])
        else
          head :not_found
        end
      end
    end
  end

  def create
    export = Current.account.exports.create!(user: Current.user)
    export.build_later
    respond_to do |format|
      format.html { redirect_to account_settings_path, notice: "Export started. You'll receive an email when it's ready." }
      format.json { render json: export.as_json(only: %i[id status created_at]), status: :accepted }
    end
  end

  private
    def ensure_export_limit_not_exceeded
      head :too_many_requests if Current.user.exports.current.count >= CURRENT_EXPORT_LIMIT
    end

    def set_export
      @export = Current.account.exports.completed.find_by(id: params[:id], user: Current.user)
    end
end
