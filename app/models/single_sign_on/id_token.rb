class SingleSignOn::IdToken
  LEEWAY = 60
  REQUIRED_CLAIMS = %w[ iss sub aud exp iat nonce ]

  def initialize(encoded, provider:)
    @encoded = encoded
    @provider = provider
  end

  def verify(nonce:)
    payload = decode
    ensure_valid_claims(payload, nonce)

    SingleSignOn::Claims.from_payload(payload)
  rescue JWT::DecodeError => error
    raise SingleSignOn::InvalidIdToken, error.message
  end

  private
    attr_reader :encoded, :provider

    def decode
      payload, _header = JWT.decode encoded, nil, true,
        algorithms: provider.signing_algorithms,
        jwks: ->(options) { { keys: provider.signing_keys(refresh: options[:kid_not_found].present?) } },
        iss: provider.issuer,
        verify_iss: true,
        aud: provider.client_id,
        verify_aud: true,
        required_claims: REQUIRED_CLAIMS,
        leeway: LEEWAY

      payload
    end

    # The jwt gem checks `iat` with no leeway, so `iat` is checked here.
    def ensure_valid_claims(payload, nonce)
      if !payload["iat"].is_a?(Numeric) || payload["iat"] > Time.now.to_i + LEEWAY
        raise SingleSignOn::InvalidIdToken, "ID token iat is not in the past"
      elsif nonce.blank? || !ActiveSupport::SecurityUtils.secure_compare(payload["nonce"].to_s, nonce)
        raise SingleSignOn::InvalidIdToken, "ID token nonce does not match"
      elsif (Array(payload["aud"]).many? || payload.key?("azp")) && payload["azp"] != provider.client_id
        raise SingleSignOn::InvalidIdToken, "ID token azp does not match"
      elsif !payload["sub"].is_a?(String) || payload["sub"].blank?
        raise SingleSignOn::InvalidIdToken, "ID token has no subject"
      end
    end
end
