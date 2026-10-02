class My::ConnectedAppsController < ApplicationController
  before_action :set_connected_apps, only: :index
  before_action :set_oauth_client, only: :destroy

  def index
  end

  def destroy
    @tokens.destroy_all

    redirect_to my_connected_apps_path, notice: "#{@client.name} has been disconnected"
  end

  private
    def set_connected_apps
      tokens = oauth_tokens.includes(:oauth_client).order(:created_at)
      @connected_apps = tokens.group_by(&:oauth_client).sort_by { |client, _| client.name.downcase }
    end

    def set_oauth_client
      @tokens = oauth_tokens.where(oauth_client_id: params.require(:id))
      @client = @tokens.first&.oauth_client or raise ActiveRecord::RecordNotFound
    end

    def oauth_tokens
      Current.identity.access_tokens.oauth
    end
end
