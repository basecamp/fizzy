class Users::CredentialsController < ApplicationController
  before_action :set_user

  def index
    @credentials = identity.credentials.order(created_at: :desc)
  end

  def new
    @creation_options = Identity::Credential.creation_options(identity: identity, display_name: @user.name)
    session[:webauthn_challenge] = @creation_options.challenge
  end

  def create
    Identity::Credential.register(
      identity: identity,
      name: params.dig(:credential, :name),
      client_data_json: credential_response[:client_data_json],
      attestation_object: credential_response[:attestation_object],
      challenge: session.delete(:webauthn_challenge),
      origin: request.base_url,
      transports: Array(credential_response[:transports])
    )

    redirect_to user_credentials_path(@user)
  end

  def destroy
    identity.credentials.find(params[:id]).destroy!
    redirect_to user_credentials_path(@user)
  end

  private
    def set_user
      @user = Current.identity.users.find(params[:user_id])
    end

    def identity
      @user.identity
    end

    def credential_response
      params.expect(credential: { response: [ :client_data_json, :attestation_object, transports: [] ] })[:response]
    end
end
