module Notifications
  class SettingsController < ApplicationController
    def show
      @collections = Current.user.collections.alphabetically
    end
  end
end
