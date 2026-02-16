class Users::CredentialsController < ApplicationController
  before_action :set_user
  before_action :set_webauthn_host

  def index
    @credentials = identity.credentials.order(created_at: :desc)
  end

  def new
    @creation_options = creation_options
    session[:webauthn_challenge] = @creation_options.challenge
  end

  def create
    public_key_credential = ActionPack::WebAuthn::PublicKeyCredential.create(
      client_data_json: decode64(credential_response[:client_data_json]),
      attestation_object: decode64(credential_response[:attestation_object]),
      challenge: session.delete(:webauthn_challenge),
      origin: request.base_url,
      transports: Array(credential_response[:transports])
    )

    identity.credentials.create!(
      name: params.dig(:credential, :name),
      credential_id: public_key_credential.id,
      public_key: public_key_credential.public_key.to_der,
      sign_count: public_key_credential.sign_count,
      transports: public_key_credential.transports
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

    def set_webauthn_host
      ActionPack::WebAuthn::Current.host = request.host
    end

    def identity
      @user.identity
    end

    def creation_options
      ActionPack::WebAuthn::PublicKeyCredential::CreationOptions.new(
        id: identity.id,
        name: identity.email_address,
        display_name: @user.name,
        resident_key: :required,
        exclude_credentials: identity.credentials.map { |c| ExcludeCredential.new(c.credential_id, c.transports) }
      )
    end

    def credential_response
      params.expect(credential: { response: [ :client_data_json, :attestation_object, transports: [] ] })[:response]
    end

    def decode64(value)
      Base64.urlsafe_decode64(value)
    end

    ExcludeCredential = Struct.new(:id, :transports)
end
