class Users::DevicesController < ApplicationController
  # GET /users/devices - Web only (view registered devices)
  def index
    @devices = Current.user.devices.order(created_at: :desc)
  end

  # POST /users/devices - API only (mobile apps register tokens)
  def create
    attrs = device_params
    device = ActionPushNative::Device.find_or_initialize_by(token: attrs[:token])
    device.owner = Current.user
    device.update!(attrs)
    head :created
  rescue ActiveRecord::RecordNotUnique
    device = ActionPushNative::Device.find_by(token: attrs[:token])
    raise unless device

    device.owner = Current.user
    device.update!(attrs)
    head :created
  rescue ActiveRecord::RecordInvalid
    head :unprocessable_entity
  end

  # DELETE /users/devices/:id - Web only
  def destroy
    Current.user.devices.find_by(id: params[:id])&.destroy
    redirect_to users_devices_path, notice: "Device removed"
  end

  private
    def device_params
      params.permit(:token, :platform, :name).tap do |p|
        p[:platform] = p[:platform].to_s.downcase
        raise ActionController::BadRequest unless p[:platform].in?(%w[apple google])
        raise ActionController::BadRequest if p[:token].blank?
      end
    end
end
