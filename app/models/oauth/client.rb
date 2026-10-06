class Oauth::Client < ApplicationRecord
  # The secret transports a confidential client may register. Either verifies
  # the secret, however it arrives: the registered method is advisory.
  SECRET_AUTH_METHODS = %w[ client_secret_post client_secret_basic ]
  AUTH_METHODS = %w[ none ] + SECRET_AUTH_METHODS

  # Registration is open, and MCP clients often register afresh on every
  # install or reconnect, so a self-registered client left without a grant
  # this long is abandoned (RFC 7591 §5).
  UNUSED_RETENTION = 30.days

  has_many :access_tokens, class_name: "Identity::AccessToken", foreign_key: :oauth_client_id, inverse_of: :oauth_client, dependent: :delete_all

  has_secure_token :client_id, length: 32

  validates :name, presence: true, length: { maximum: 255 }
  validates :client_id, uniqueness: true, allow_nil: true
  validates :redirect_uris, presence: true
  validates :token_endpoint_auth_method, inclusion: { in: AUTH_METHODS }
  validate :redirect_uris_are_valid

  before_create :generate_client_secret, if: :confidential?

  attribute :redirect_uris, default: -> { [] }
  attribute :scopes, default: -> { %w[ read ] }

  scope :trusted, -> { where trusted: true }
  scope :dynamically_registered, -> { where dynamically_registered: true }

  # A grant touches its client when it is created or destroyed, so updated_at
  # is the last grant activity: an app the user disconnected yesterday is not
  # swept for having registered long ago.
  scope :stale, -> { dynamically_registered.where.missing(:access_tokens).where(updated_at: ...UNUSED_RETENTION.ago) }

  def self.cleanup
    stale.find_each(&:destroy_if_still_unused)
  end

  # The sweep and #redeem take the same row lock, so a grant either lands
  # before the recheck, which then spares the client, or finds the client
  # already gone and is never issued. There is no foreign key to refuse a
  # token for a deleted client. The recheck is the whole stale test, not just
  # the absence of tokens: a grant issued and revoked since the sweep picked
  # this client has touched it, and restarted its retention period.
  def destroy_if_still_unused
    with_lock do
      destroy if self.class.stale.exists?(id)
    end
  end

  # Raises ActiveRecord::RecordNotFound if the client has been swept since it
  # was read.
  def redeem(authorization_code, identity:, permission:)
    with_lock do
      identity.access_tokens.redeem authorization_code, oauth_client: self, permission: permission
    end
  end

  def confidential?
    token_endpoint_auth_method.in?(SECRET_AUTH_METHODS)
  end

  def authenticate_secret(secret)
    confidential? && client_secret.present? && secret.is_a?(String) && secret.present? &&
      ActiveSupport::SecurityUtils.secure_compare(client_secret, secret)
  end

  def allows_redirect?(uri)
    redirect_uris.include?(uri) || (loopback_uri?(uri) && matching_loopback?(uri))
  end

  # Whether we may send the browser to this redirect before the user has seen
  # the consent screen. A self-registered https host is one nobody vetted, so
  # bouncing to it unprompted would make us an open redirector (RFC 9700 §4.11.2).
  def vetted_redirect?(uri)
    !dynamically_registered? || loopback_uri?(uri)
  end

  def allows_scope?(requested_scope)
    requested = requested_scope.to_s.split
    requested.present? && requested.all? { |s| scopes.include?(s) }
  end

  private
    def generate_client_secret
      self.client_secret ||= self.class.generate_unique_secure_token
    end

    def redirect_uris_are_valid
      redirect_uris.each { |uri| validate_redirect_uri(uri) }
    end

    def validate_redirect_uri(uri)
      parsed = URI.parse(uri)

      unless parsed.fragment.nil?
        errors.add :redirect_uris, "must not contain fragments"
      end

      if dynamically_registered? && !valid_loopback_uri?(parsed) && !valid_https_uri?(parsed)
        errors.add :redirect_uris, "must be an https or local loopback URI for dynamically registered clients"
      end
    rescue URI::InvalidURIError
      errors.add :redirect_uris, "includes an invalid URI"
    end

    def loopback_uri?(uri)
      Oauth.loopback_host?(URI.parse(uri).host)
    rescue URI::InvalidURIError
      false
    end

    def valid_loopback_uri?(parsed)
      parsed.scheme == "http" && Oauth.plain_authority?(parsed) && Oauth.loopback_host?(parsed.host)
    end

    def valid_https_uri?(parsed)
      parsed.scheme == "https" && Oauth.plain_authority?(parsed) && !Oauth.loopback_host?(parsed.host)
    end

    # Only the port may vary, and only for an http loopback redirect (RFC 8252
    # §7.3): https or a native scheme on loopback stays exact. The host and any
    # userinfo must match too:
    # 127.0.0.1, localhost and ::1 are not interchangeable, and localhost
    # may not even resolve to loopback (RFC 8252 §8.3).
    def matching_loopback?(uri)
      parsed = URI.parse(uri)

      Oauth.plain_authority?(parsed) && redirect_uris.any? do |redirect_uri|
        redirect = URI.parse(redirect_uri)

        redirect.scheme == "http" && parsed.scheme == "http" &&
          Oauth.loopback_host?(redirect.host) &&
          redirect.host.casecmp?(parsed.host.to_s) &&
          redirect.userinfo == parsed.userinfo &&
          redirect.path == parsed.path &&
          redirect.query == parsed.query &&
          parsed.fragment.nil?
      end
    rescue URI::InvalidURIError
      false
    end
end
