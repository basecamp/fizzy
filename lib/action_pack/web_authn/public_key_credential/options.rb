class ActionPack::WebAuthn::PublicKeyCredential::Options
  CHALLENGE_LENGTH = 32
  USER_VERIFICATION_OPTIONS = [ :required, :preferred, :discouraged ].freeze

  attr_reader :user_verification, :relying_party

  def initialize(user_verification: :preferred, relying_party: ActionPack::WebAuthn.relying_party)
    @user_verification = user_verification.to_sym
    @relying_party = relying_party

    unless USER_VERIFICATION_OPTIONS.include?(user_verification)
      raise ArgumentError, "Invalid user verification option: #{user_verification.inspect}"
    end
  end

  # Returns a Base64URL-encoded random challenge. The challenge is generated
  # once and memoized for the lifetime of this object.
  #
  # The challenge must be stored server-side and verified when the client
  # responds, to prevent replay attacks.
  def challenge
    @challenge ||= Base64.urlsafe_encode64(
      SecureRandom.random_bytes(CHALLENGE_LENGTH),
      padding: false
    )
  end
end
