class Users::DevicesController < ApplicationController
  before_action :set_devices

  rescue_from ActiveRecord::NotNullViolation, ArgumentError, with: :bad_request

  def index
  end

  def create
    @devices.create!(device_params)
    head :created
  end

  def destroy
    if params[:token].present?
      @devices.destroy_by(token: params[:token])
      head :no_content
    else
      @devices.destroy_by(id: params[:id])
      redirect_to users_devices_path, notice: "Device removed"
    end
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

    def bad_request
      head :bad_request
    end
end
