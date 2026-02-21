class DevicesController < ApplicationController
  disallow_account_scope
  before_action :set_device, only: :destroy

  def index
    @devices = Current.identity.devices.order(created_at: :desc)
  end

  def create
    ApplicationPushDevice.register(session: Current.session, **device_params)
    head :created
  end

  def destroy
    @device.destroy
    respond_to do |format|
      format.html { redirect_to saas.devices_path, notice: "Device removed" }
      format.json { head :no_content }
    end
  end

  private
    def set_device
      @device = Current.identity.devices.find_by(token: params[:id]) || Current.identity.devices.find(params[:id])
    end

    def device_params
      params.require([ :token, :platform ])
      params.permit(:token, :platform, :name).to_h.symbolize_keys
    end
end
