class SingleSignOn::AuthorizationRequest
  EXPIRATION_TIME = 10.minutes
  ATTRIBUTES = %i[ state nonce code_verifier return_to created_at ]

  attr_reader(*ATTRIBUTES)

  class << self
    def start(return_to: nil)
      new \
        state: SecureRandom.urlsafe_base64(32),
        nonce: SecureRandom.urlsafe_base64(32),
        code_verifier: SecureRandom.urlsafe_base64(48),
        return_to: return_to,
        created_at: Time.current.to_i
    end

    def from_session(attributes)
      new(**attributes.to_h.symbolize_keys.slice(*ATTRIBUTES))
    end
  end

  def initialize(state:, nonce:, code_verifier:, return_to:, created_at:)
    @state = state
    @nonce = nonce
    @code_verifier = code_verifier
    @return_to = return_to
    @created_at = created_at
  end

  def to_session
    ATTRIBUTES.index_with { |attribute| public_send(attribute) }.stringify_keys
  end

  def url(redirect_uri:)
    provider.authorization_url(redirect_uri:, state:, nonce:, code_challenge:)
  end

  def complete(params, redirect_uri:)
    ensure_successful_response(params)
    provider.claims_for(code: params[:code].to_s, redirect_uri:, code_verifier:, nonce:)
  end

  def expired?
    created_at.to_i < EXPIRATION_TIME.ago.to_i
  end

  private
    def provider
      @provider ||= SingleSignOn.provider
    end

    def code_challenge
      Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false)
    end

    def ensure_successful_response(params)
      if expired?
        raise SingleSignOn::AuthorizationError, "Authorization request expired"
      elsif params[:error].present?
        raise SingleSignOn::AuthorizationError,
          "#{provider.issuer} returned #{params[:error].to_s.first(64).inspect}"
      elsif params[:iss].present? && params[:iss] != provider.issuer
        raise SingleSignOn::AuthorizationError,
          "Authorization response came from #{params[:iss].to_s.first(256).inspect}"
      elsif params[:code].blank?
        raise SingleSignOn::AuthorizationError, "Authorization response has no code"
      end
    end
end
