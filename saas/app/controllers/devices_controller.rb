class DevicesController < ApplicationController
  def index
    @devices = Current.user.devices.order(created_at: :desc)
  end

  def create
    ApplicationPushDevice.register(owner: Current.user, **device_params)
    head :created
  rescue ArgumentError
    head :bad_request
  end

  def destroy
    if params[:token].present?
      Current.user.devices.destroy_by(token: params[:token])
      head :no_content
    else
      Current.user.devices.destroy_by(id: params[:id])
      redirect_to devices_path, notice: "Device removed"
    end
  end

  private
    def device_params
      params.require([ :token, :platform ])
      params.permit(:token, :platform, :name).to_h.symbolize_keys
    end
end
