module Authentication::ViaOidc
  extend ActiveSupport::Concern

  private
    def authenticate_with_oidc(auth_hash)
      identity = Identity.find_or_create_from_oidc(auth_hash)

      if identity.present?
        start_new_session_for identity
        redirect_to after_authentication_url
      else
        authentication_failed(message: "Something went wrong using your identity provider.")
      end
    end
end
