class My::PasskeysController < ApplicationController
  include ActionPack::Passkey::Request

  before_action :set_passkey, only: %i[ edit update destroy ]

  def index
    @passkeys = Current.identity.passkeys.order(name: :asc, created_at: :desc)
    @creation_options = passkey_creation_options(holder: Current.identity)
  end

  def create
    passkey = Current.identity.passkeys.register(passkey_creation_params)

    redirect_to edit_my_passkey_path(passkey, created: true)
  end

  def edit
  end

  def update
    @passkey.update!(params.expect(passkey: [ :name ]))
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
end
