class Signup::BaseController < ApplicationController
  require_untenanted_access
  before_action :redirect_if_local_auth

  # TODO: Remove this auth before launch.
  http_basic_authenticate_with(
    name: Rails.env.test? ? "testname" : Rails.application.credentials.account_signup_http_basic_auth.name,
    password: Rails.env.test? ? "testpassword" : Rails.application.credentials.account_signup_http_basic_auth.password
  )

  attr_reader :authenticated_identity

  private
    def signup_storage
      session[:signup] ||= {}
    end

    def reset_signup_storage
      session.delete(:signup)
    end

    def authenticated_identity=(identity)
      @authenticated_identity = identity
      signup_storage["identity_id"] = identity.try(:id)
    end

    def set_authenticated_identity
      if identity_id = signup_storage["identity_id"]
        @authenticated_identity = SignalId::Identity.find_by(id: identity_id)
      end
    end

    def redirect_to_account(account)
      redirect_to account.signal_account.owner.remote_login_url(proceed_to: root_path),
                  allow_other_host: true
    end

    def redirect_if_local_auth
      render plain: "Unauthorized", status: :unauthorized if Rails.application.config.x.local_authentication
    end
end
