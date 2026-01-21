class DevicesController < ApplicationController
  before_action :set_device, only: :destroy

  def index
    @devices = Current.user.devices.order(created_at: :desc)
  end

  def create
    ApplicationPushDevice.register(owner: Current.user, **device_params)
    head :created
  end

  def destroy
    @device.destroy
    respond_to do |format|
      format.html { redirect_to devices_path, notice: "Device removed" }
      format.json { head :no_content }
    end
  end

  private
    def set_device
      @device = Current.user.devices.find_by(token: params[:id]) || Current.user.devices.find(params[:id])
    end

    def device_params
      params.require([ :token, :platform ])
      params.permit(:token, :platform, :name).to_h.symbolize_keys
    end
end
