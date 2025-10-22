class IdentitiesController < ApplicationController
  include InternalApi

  def link
    IdentityProvider::LocalBackend.link(email_address: params[:email_address], to: params[:to])
    head :ok
  end

  def unlink
    IdentityProvider::LocalBackend.unlink(email_address: params[:email_address], from: params[:from])
    head :ok
  end

  def change_email_address
    IdentityProvider::LocalBackend.change_email_address(from: params[:from], to: params[:to], tenant: params[:tenant])
    head :ok
  end

  def send_magic_link
    code = IdentityProvider::LocalBackend.send_magic_link(params[:email_address])
    render json: { code: code }
  end
end
