class Identity::EmailAddresses::ConfirmationsController < ApplicationController
  require_untenanted_access

  before_action :set_identity
  rate_limit to: 3, within: 1.hour, only: :create

  def show
  end

  def create
    @identity.change_email_address_using_token(token)

    # Redirect to the tenant that initiated the change
    tenant = SignedGlobalID.parse(token, for: Identity::EmailAddressChangeable::EMAIL_CHANGE_TOKEN_PURPOSE)&.params&.fetch("tenant")

    if tenant
      redirect_to "#{tenant}/users/#{Current.user.id}/edit"
    else
      redirect_to session_menu_path
    end
  rescue ArgumentError => e
    flash[:alert] = e.message
    render :show, status: :unprocessable_entity
  end

  private
    def set_identity
      @identity = Current.identity
    end

    def token
      params.expect :email_address_token
    end
end
