class ActionPack::WebAuthn::PublicKeyCredential::Options
  include ActiveModel::API
  include ActiveModel::Attributes

  CHALLENGE_LENGTH = 32
  USER_VERIFICATION_OPTIONS = %i[ required preferred discouraged ].freeze

  attribute :user_verification, default: :preferred
  attribute :relying_party, default: -> { ActionPack::WebAuthn.relying_party }
  attribute :challenge_expiration

  validates :user_verification, inclusion: { in: USER_VERIFICATION_OPTIONS }

  def initialize(attributes = {})
    super
    self.user_verification = user_verification.to_sym
  end

  def validate!
    super
  rescue ActiveModel::ValidationError
    raise ActionPack::WebAuthn::InvalidOptionsError, errors.full_messages.to_sentence
  end

  def inspect
    attributes_string = attributes.map { |name, value| "#{name}: #{value.inspect}" }.join(", ")
    "#<#{self.class.name} #{attributes_string}>"
  end

  # Returns a Base64URL-encoded signed challenge containing a random nonce and
  # an embedded timestamp. The challenge is generated once and memoized for the
  # lifetime of this object.
  #
  # The timestamp allows the server to reject stale challenges. The expiration
  # window is configurable per-ceremony via
  # +config.action_pack.web_authn.creation_challenge_expiration+ and
  # +config.action_pack.web_authn.request_challenge_expiration+, or per-instance
  # via the +challenge_expiration+ attribute.
  def challenge
    @challenge ||= Base64.urlsafe_encode64(
      ActionPack::WebAuthn.challenge_verifier.generate(
        Base64.strict_encode64(SecureRandom.random_bytes(CHALLENGE_LENGTH)),
        expires_in: challenge_expiration
      ),
      padding: false
    )
  end
end
