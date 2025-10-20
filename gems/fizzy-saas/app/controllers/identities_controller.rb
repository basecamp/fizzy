class IdentitiesController < ApplicationController
  include InternalApi

  def link
    IdentityProvider::Simple.link(email_address: params[:email_address], to: params[:to])
    head :ok
  end

  def unlink
    IdentityProvider::Simple.unlink(email_address: params[:email_address], from: params[:from])
    head :ok
  end

  def change_email_address
    IdentityProvider::Simple.change_email_address(from: params[:from], to: params[:to], tenant: params[:tenant])
    head :ok
  end

  def send_magic_link
    code = IdentityProvider::Simple.send_magic_link(params[:email_address])
    render json: { code: code }
  end
end
