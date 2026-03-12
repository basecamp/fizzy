class My::PasskeysController < ApplicationController
  include ActionPack::Passkey::Request

  before_action :set_passkey, only: %i[ edit update destroy ]

  def index
    @passkeys = Current.identity.passkeys.order(name: :asc, created_at: :desc)
    @creation_options = ActionPack::Passkey.creation_options(holder: Current.identity)
  end

  def create
    passkey = Current.identity.passkeys.register(passkey: passkey_params)

    redirect_to edit_my_passkey_path(passkey, created: true)
  end

  def edit
  end

  def update
    @passkey.update!(passkey_params_for_update)
    redirect_to my_passkeys_path
  end

  def destroy
    @passkey.destroy!
    redirect_to my_passkeys_path
  end

  private
    def set_passkey
      @passkey = Current.identity.passkeys.find(params[:id])
    end

    def passkey_params_for_update
      params.expect(passkey: [ :name ])
    end

    def passkey_params
      params.expect(passkey: [ :client_data_json, :attestation_object, transports: [] ])
    end
end
