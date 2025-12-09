module WebauthnRelyingParty
  extend ActiveSupport::Concern

  private
    def webauthn_relying_party
      @webauthn_relying_party ||= WebAuthn::RelyingParty.new(
        allowed_origins: webauthn_allowed_origins,
        id: webauthn_rp_id,
        name: "Fizzy"
      )
    end

    def webauthn_rp_id
      configured_rp_id = Rails.application.config.x.webauthn&.rp_id
      configured_rp_id.presence || default_webauthn_rp_id
    end

    def webauthn_allowed_origins
      configured_origins = Rails.application.config.x.webauthn&.allowed_origins
      configured_origins.presence || default_webauthn_allowed_origins
    end

    def default_webauthn_rp_id
      if Rails.env.development?
        "fizzy.localhost"
      elsif Rails.env.test?
        "localhost"
      else
        request.host
      end
    end

    def default_webauthn_allowed_origins
      if Rails.env.development?
        # Allow both HTTP dev server and HTTPS (used by some password managers)
        [
          "http://fizzy.localhost:3006",
          "https://fizzy.localhost"
        ]
      elsif Rails.env.test?
        [ "http://localhost" ]
      else
        [ "#{request.protocol}#{request.host_with_port}" ]
      end
    end

    # Encode a user ID as base64url for WebAuthn JSON serialization
    # The WebAuthn spec requires user.id to be transmitted as base64url
    def encode_webauthn_user_id(user_id)
      Base64.urlsafe_encode64(user_id.to_s, padding: false)
    end
end
