class Users::DevicesController < ApplicationController
  before_action :set_devices

  def index
  end

  def create
    device = @devices.find_or_initialize_by(uuid: params.require(:uuid))
    device.update!(device_params)
    head :created
  rescue ArgumentError
    head :bad_request
  end

  def destroy
    @devices.destroy_by(id: params[:id])
    redirect_to users_devices_path, notice: "Device removed"
  end

  private
    def set_devices
      @devices = Current.user.devices.order(created_at: :desc)
    end

    def device_params
      params.permit(:token, :platform, :name).tap do |permitted|
        permitted[:platform] = permitted[:platform].to_s.downcase if permitted[:platform].present?
      end
    end
end
