class IdentitiesController < ApplicationController
  include InternalApi

  def link
    Identity.link(email_address: params[:email_address], to: params[:to])
    head :ok
  end

  def unlink
    Identity.unlink(email_address: params[:email_address], from: params[:from])
    head :ok
  end

  def change_email_address
    Membership.change_email_address(from: params[:from], to: params[:to], tenant: params[:tenant])
    head :ok
  end

  def send_magic_link
    magic_link = Identity.find_by(email_address: params[:email_address])&.send_magic_link
    render json: { code: magic_link&.code }
  end
end
