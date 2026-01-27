class SessionsController < ApplicationController
  disallow_account_scope
  require_unauthenticated_access except: :destroy
  rate_limit to: 10, within: 3.minutes, only: :create, with: :rate_limit_exceeded

  layout "public"

  def new
  end

  def create
    if identity = Identity.find_by(email_address: email_address)
      sign_in identity
    elsif Account.accepting_signups?
      sign_up
    else
      redirect_to_fake_session_magic_link email_address
    end
  end

  def destroy
    terminate_session

    respond_to do |format|
      format.html { redirect_to_logout_url }
      format.json { head :no_content }
    end
  end

  private
    def magic_link_from_sign_in_or_sign_up
      if identity = Identity.find_by_email_address(email_address)
        identity.send_magic_link
      else
        signup = Signup.new(email_address: email_address)
        signup.create_identity if signup.valid?(:identity_creation) && Account.accepting_signups?
      end
    end

    def email_address
      params.expect(:email_address)
    end

    def rate_limit_exceeded
      rate_limit_exceeded_message = "Try again later."

      respond_to do |format|
        format.html { redirect_to new_session_path, alert: rate_limit_exceeded_message }
        format.json { render json: { message: rate_limit_exceeded_message }, status: :too_many_requests }
      end
    end

    def sign_in(identity)
      redirect_to_session_magic_link identity.send_magic_link
    end

    def sign_up
      signup = Signup.new(email_address: email_address)

      if signup.valid?(:identity_creation)
        magic_link = signup.create_identity
        redirect_to_session_magic_link magic_link
      else
        respond_to do |format|
          format.html { redirect_to new_session_path, alert: "Something went wrong" }
          format.json { render json: { message: "Something went wrong" }, status: :unprocessable_entity }
        end
      end
    end
end
