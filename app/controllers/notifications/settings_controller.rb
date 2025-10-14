class Notifications::SettingsController < ApplicationController
  before_action :set_settings

  def show
    @collections = Current.user.collections.alphabetically
  end

  def update
    @settings.update!(settings_params)
    redirect_to notifications_settings_path, notice: "Settings updated"
  end

  private
    def set_settings
      @settings = Current.user.settings
    end

    def settings_params
      params.expect(user_settings: :bundle_email_frequency)
    end
end
