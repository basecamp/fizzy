class Users::DevicesController < ApplicationController
  def index
    @devices = Current.user.devices.order(created_at: :desc)
  end

  def create
    attrs = device_params
    device = Current.user.devices.find_or_initialize_by(uuid: attrs[:uuid])
    device.update!(token: attrs[:token], name: attrs[:name], platform: attrs[:platform])
    head :created
  rescue ActiveRecord::RecordInvalid
    head :unprocessable_entity
  end

  def destroy
    Current.user.devices.find_by(id: params[:id])&.destroy
    redirect_to users_devices_path, notice: "Device removed"
  end

  private
    def device_params
      params.permit(:uuid, :token, :platform, :name).tap do |p|
        p[:platform] = p[:platform].to_s.downcase
        raise ActionController::BadRequest unless p[:platform].in?(%w[apple google])
        raise ActionController::BadRequest if p[:uuid].blank?
        raise ActionController::BadRequest if p[:token].blank?
      end
    end
end
