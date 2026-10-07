class My::ConnectedAppsController < ApplicationController
  disallow_oauth_grants

  before_action :set_connected_apps, only: :index
  before_action :set_oauth_client, only: :destroy

  def index
    @webhooks_by_client = Webhook.set_up_through(@connected_apps.map(&:first), identity: Current.identity)
      .includes(:board, :account).ordered.group_by(&:created_via_id)
  end

  # Webhooks an app set up are the account's, so disconnecting it leaves them
  # unless the person also chose to remove them. Only the ones they were shown
  # go: one the app added since the confirmation was drawn stays. They go
  # first, so if removing one fails, the app is still listed to try again.
  def destroy
    if remove_webhooks?
      Webhook.set_up_through(@client, identity: Current.identity).where(id: params.expect(webhook_ids: [])).destroy_all
    end

    @tokens.destroy_all

    redirect_to my_connected_apps_path, notice: "#{@client.name} has been disconnected"
  end

  private
    def set_connected_apps
      tokens = oauth_tokens.unlapsed.includes(:oauth_client).order(:created_at)
      @connected_apps = tokens.group_by(&:oauth_client).sort_by { |client, _| client.name.downcase }
    end

    def set_oauth_client
      @tokens = oauth_tokens.where(oauth_client_id: params.require(:id))
      @client = @tokens.first&.oauth_client or raise ActiveRecord::RecordNotFound
    end

    def oauth_tokens
      Current.identity.access_tokens.oauth
    end

    def remove_webhooks?
      ActiveModel::Type::Boolean.new.cast(params[:remove_webhooks])
    end
end
