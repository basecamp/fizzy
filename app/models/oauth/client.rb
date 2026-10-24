class Oauth::Client < ApplicationRecord
  # The secret transports a confidential client may register. Either verifies
  # the secret, however it arrives: the registered method is advisory.
  SECRET_AUTH_METHODS = %w[ client_secret_post client_secret_basic ]
  AUTH_METHODS = %w[ none ] + SECRET_AUTH_METHODS

  # Registration is open, and MCP clients often register afresh on every
  # install or reconnect, so a self-registered client left without a grant
  # this long is abandoned (RFC 7591 §5).
  UNUSED_RETENTION = 30.days

  has_many :access_tokens, class_name: "Identity::AccessToken", foreign_key: :oauth_client_id, inverse_of: :oauth_client, dependent: :destroy

  has_secure_token :client_id, length: 32

  # A code exchange locks the client and then issues a grant (#redeem).
  # Destroying a client takes the same lock before its grants cascade, in the
  # same order, so no grant can land after the cascade and be stranded.
  before_destroy :lock_client, prepend: true

  validates :name, presence: true, length: { maximum: 255 }
  validates :client_id, uniqueness: true, allow_nil: true
  # Registration is open and unauthenticated, so what it stores is bounded:
  # a few callbacks, each no longer than a URL browsers reliably carry.
  MAXIMUM_REDIRECT_URIS = 10
  MAXIMUM_REDIRECT_URI_LENGTH = 2000

  validates :redirect_uris, presence: true, length: { maximum: MAXIMUM_REDIRECT_URIS }
  validates :token_endpoint_auth_method, inclusion: { in: AUTH_METHODS }
  validate :redirect_uris_are_valid
  validate :added_https_hosts_are_vetted, if: -> { dynamically_registered? && (new_record? || redirect_uris_changed?) }

  # A confidential client's secret is stored as a digest (TokenDigester). The
  # raw secret exists only in memory on the record that generated it, for the
  # registration response, the one time it's shown.
  attribute :raw_client_secret, :string

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
  rescue ActiveRecord::RecordNotFound
    # Already gone, deleted since the sweep picked it.
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
    confidential? && client_secret_digest.present? && TokenDigester.verify(secret, client_secret_digest)
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
    # Takes the row lock without reloading, since lock! refuses a record with
    # unsaved changes and destroy otherwise ignores them. Resetting the grants
    # makes the cascade see every grant committed before the lock.
    def lock_client
      self.class.lock.where(id: id).pluck(:id)
      access_tokens.reset
    end

    def generate_client_secret
      self.raw_client_secret ||= Identity::AccessToken.generate_token(:client_secret)
      self.client_secret_digest = TokenDigester.digest(raw_client_secret)
    end

    def redirect_uris_are_valid
      if redirect_uris.all? { |uri| uri.is_a?(String) && uri.length <= MAXIMUM_REDIRECT_URI_LENGTH }
        redirect_uris.each { |uri| validate_redirect_uri(uri) }
      else
        errors.add :redirect_uris, "must each be a URI of at most #{MAXIMUM_REDIRECT_URI_LENGTH} characters"
      end
    end

    def validate_redirect_uri(uri)
      parsed = URI.parse(uri)

      unless parsed.fragment.nil?
        errors.add :redirect_uris, "must not contain fragments"
      end

      if dynamically_registered? && !Oauth.dcr_redirect_shape?(parsed)
        errors.add :redirect_uris, "must be a local loopback, https or allowed app-scheme URI for dynamically registered clients"
      end
    rescue URI::InvalidURIError
      errors.add :redirect_uris, "includes an invalid URI"
    end

    # http only: an app scheme naming a loopback host (cursor://localhost) is
    # dispatched to an app, not served on loopback (RFC 8252 §7.3).
    def loopback_uri?(uri)
      parsed = URI.parse(uri)
      parsed.scheme&.downcase == "http" && Oauth.loopback_host?(parsed.host)
    rescue URI::InvalidURIError
      false
    end

    # Judged only on the https hosts a write adds, never on those the client
    # already holds, so taking a host off the list leaves every client that
    # registered it working (Oauth.dcr_allowed_https_hosts).
    def added_https_hosts_are_vetted
      unvetted = https_hosts(redirect_uris) - https_hosts(new_record? ? [] : redirect_uris_was)
      unvetted.reject! { |host| Oauth.dcr_allowed_https_host?(host) }

      if unvetted.any?
        errors.add :redirect_uris, "names an https host not allowed for dynamic registration: #{unvetted.join(", ")}"
      end
    end

    def https_hosts(uris)
      Array(uris).filter_map do |uri|
        parsed = URI.parse(uri.to_s)
        parsed.host.to_s.downcase if parsed.scheme&.downcase == "https"
      rescue URI::InvalidURIError
        nil
      end.uniq
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
