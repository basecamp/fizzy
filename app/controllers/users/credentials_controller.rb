class Users::CredentialsController < ApplicationController
  before_action :set_credential, only: %i[ edit update destroy ]

  def index
    @credentials = Current.identity.credentials.order(name: :asc, created_at: :desc)
  end

  def new
    @disable_view_transition = true
    @creation_options = Identity::Credential.creation_options(identity: Current.identity, display_name: Current.user.name)
    session[:webauthn_challenge] = @creation_options.challenge
  end

  def create
    credential = Current.identity.credentials.register(
      passkey: passkey_params,
      challenge: session.delete(:webauthn_challenge)
    )

    render json: { location: edit_user_credential_path(Current.user, credential, created: true) }
  rescue ActionPack::WebAuthn::Authenticator::Response::InvalidResponseError => error
    render json: { error: error.message }, status: :unprocessable_entity
  end

  def edit
  end

  def update
    @credential.update!(credential_params)
    redirect_to user_credentials_path(Current.user)
  end

  def destroy
    @credential.destroy!
    redirect_to user_credentials_path(Current.user)
  end

  private
    def set_credential
      @credential = Current.identity.credentials.find(params[:id])
    end

    def credential_params
      params.expect(credential: [ :name ])
    end

    def passkey_params
      params.expect(passkey: [ :client_data_json, :attestation_object, transports: [] ])
    end
end
