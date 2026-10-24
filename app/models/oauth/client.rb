class Oauth::Client < ApplicationRecord
  # The secret transports a confidential client may register. Either verifies
  # the secret, however it arrives: the registered method is advisory.
  SECRET_AUTH_METHODS = %w[ client_secret_post client_secret_basic ]
  AUTH_METHODS = %w[ none ] + SECRET_AUTH_METHODS

  # Registration is open, and MCP clients often register afresh on every
  # install or reconnect, so a self-registered client left without a grant
  # this long is abandoned (RFC 7591 §5).
  UNUSED_RETENTION = 30.days

  # The grants a client may obtain at the authorization and token endpoints.
  # An allowlist, so a client is refused any grant type it doesn't list.
  GRANT_TYPES = %w[ authorization_code refresh_token ]

  # Personal access tokens are issued by this first-party client, as bc3's are
  # by bc-personal-access, so they're one-off access tokens of the same kind
  # as every other. It is provisioned by a migration and on first use, never
  # registered: the sweep, which takes only self-registered clients, leaves it
  # alone. It is listed for no grant type, so the authorization and token
  # endpoints never mint, refresh or exchange its tokens: only
  # My::AccessTokensController issues them. Its client_id has a hyphen, which
  # no generated client_id (base58) can, so no other client can ever claim it.
  PERSONAL_ACCESS_CLIENT_ID = "fizzy-personal-access"
  PERSONAL_ACCESS_ATTRIBUTES = { client_id: PERSONAL_ACCESS_CLIENT_ID, name: "Personal Access Tokens",
    trusted: true, dynamically_registered: false, redirect_uris: [], scopes: %w[ read write ], token_endpoint_auth_method: "none" }

  has_many :access_tokens, class_name: "Identity::AccessToken", foreign_key: :oauth_client_id, inverse_of: :oauth_client, dependent: :destroy

  has_secure_token :client_id, length: 32

  # A code exchange locks the client and then issues a grant (#redeem).
  # Destroying a client takes the same lock before its grants cascade, in the
  # same order, so no grant can land after the cascade and be stranded.
  before_destroy :lock_client, prepend: true

  # Destroying the issuer would cascade to every client-backed personal access
  # token on the install.
  before_destroy :refuse_to_destroy_personal_access, prepend: true

  validates :name, presence: true, length: { maximum: 255 }
  validates :client_id, uniqueness: true, allow_nil: true
  # Registration is open and unauthenticated, so what it stores is bounded:
  # a few callbacks, each no longer than a URL browsers reliably carry.
  MAXIMUM_REDIRECT_URIS = 10
  MAXIMUM_REDIRECT_URI_LENGTH = 2000

  # A client that only fronts a protected resource exchanges tokens and never
  # sends anyone through authorization, and the personal access client issues
  # personal access tokens without one, so neither registers a redirect.
  validates :redirect_uris, presence: true, unless: -> { personal_access? || protected_resource? }
  validates :redirect_uris, length: { maximum: MAXIMUM_REDIRECT_URIS }
  validates :token_endpoint_auth_method, inclusion: { in: AUTH_METHODS }
  validate :redirect_uris_are_valid
  validate :protected_resource_is_valid

  # A confidential client's secret is stored as a digest (TokenDigester). The
  # raw secret exists only in memory on the record that generated it, for the
  # registration response, the one time it's shown.
  attribute :raw_client_secret, :string

  before_create :generate_client_secret, if: :confidential?

  # Self-registration is the client's own act; any other client is
  # provisioned by an operator.
  after_create_commit -> { Oauth::Audit.record "client.registered", client: self, actor: dynamically_registered? ? "client" : "admin" }

  attribute :redirect_uris, default: -> { [] }
  attribute :scopes, default: -> { %w[ read ] }

  scope :trusted, -> { where trusted: true }
  scope :dynamically_registered, -> { where dynamically_registered: true }

  # A grant touches its client when it is created or destroyed, so updated_at
  # is the last grant activity: an app the user disconnected yesterday is not
  # swept for having registered long ago.
  scope :stale, -> { dynamically_registered.where.missing(:access_tokens).where(updated_at: ...UNUSED_RETENTION.ago) }

  scope :personal_access, -> { where client_id: PERSONAL_ACCESS_CLIENT_ID }

  class << self
    def cleanup
      Oauth.cleanup_step :stale_clients do
        stale.find_each(&:destroy_if_still_unused)
      end
    end

    # A fresh install loads the schema rather than running migrations, so the
    # issuer may not exist yet when the first personal access token is made.
    # Two first uses can race: the loser either hits the unique index, which
    # create_or_find_by! answers by finding on client_id alone, or, when the
    # winner committed before its uniqueness validation ran, fails that
    # validation, and then finds the winner's row the same way.
    def personal_access_issuer
      personal_access.take || create_or_find_by!(client_id: PERSONAL_ACCESS_CLIENT_ID) { it.assign_attributes PERSONAL_ACCESS_ATTRIBUTES }
    rescue ActiveRecord::RecordInvalid
      personal_access.take or raise
    end
  end

  # The hosted MCP server's own client, by the id its deployment names
  # (FIZZY_MCP_EXCHANGE_CLIENT_ID).
  MCP_CLIENT_ID = "fizzy-mcp-server"

  # Creates or converges an MCP server's client (bin/rails
  # oauth:provision_mcp_client). A new one gets a secret nobody holds, so it
  # can't authenticate until oauth:mint_client_secret gives it one; an
  # existing one keeps the secret it has.
  #
  # Each client fronts one resource, so each configured resource needs a
  # client of its own: one already fronting another resource that's still
  # configured is refused rather than repointed, which would strand every
  # grant audienced to that resource. One whose resource has been dropped
  # from the configuration may move.
  def self.provision_mcp_client!(protected_resource:, client_id: MCP_CLIENT_ID)
    find_or_initialize_by(client_id: client_id).tap do |client|
      if client.protected_resource != protected_resource && client.delegation_client?
        raise ArgumentError, "#{client_id} already fronts #{client.protected_resource}; give #{protected_resource} a client of its own"
      else
        client.update! name: "Fizzy MCP server", protected_resource: protected_resource, scopes: %w[ read write ],
          redirect_uris: [], token_endpoint_auth_method: "client_secret_post", dynamically_registered: false, trusted: false
      end
    end
  end

  # The sweep and #redeem take the same row lock, so a grant either lands
  # before the recheck, which then spares the client, or finds the client
  # already gone and is never issued. There is no foreign key to refuse a
  # token for a deleted client. The recheck is the whole stale test, not just
  # the absence of tokens: a grant issued and revoked since the sweep picked
  # this client has touched it, and restarted its retention period.
  #
  # The event follows the lock's commit, so it reports a sweep that happened.
  def destroy_if_still_unused
    swept = with_lock do
      destroy if self.class.stale.exists?(id)
    end

    Oauth::Audit.record "client.swept", client: self, actor: "system", reason: "unused" if swept
  rescue ActiveRecord::RecordNotFound
    # Already gone, deleted since the sweep picked it.
  end

  # Raises ActiveRecord::RecordNotFound if the client has been swept since it
  # was read.
  def redeem(authorization_code, identity:, permission:, **attributes)
    with_lock do
      identity.access_tokens.redeem authorization_code, oauth_client: self, permission: permission, **attributes
    end
  end

  # Replaces an operator-provisioned client's secret with a fresh one and
  # returns it, the only time it's shown. The old secret stops authenticating
  # as soon as this commits.
  def rotate_secret!
    if dynamically_registered? || !confidential?
      raise ArgumentError, "only an operator-provisioned confidential client's secret can be minted"
    end

    Identity::AccessToken.generate_token(:client_secret).tap do |secret|
      update! client_secret_digest: TokenDigester.digest(secret)
    end
  end

  def personal_access?
    client_id == PERSONAL_ACCESS_CLIENT_ID
  end

  def grant_types
    personal_access? ? [] : GRANT_TYPES
  end

  def allows_grant_type?(grant_type)
    grant_type.in?(grant_types)
  end

  def confidential?
    token_endpoint_auth_method.in?(SECRET_AUTH_METHODS)
  end

  # RFC 6749 §2.1's client types, as bc3 labels its metrics.
  def client_type
    confidential? ? "confidential" : "public"
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

  # The protected resource this client fronts, if any: the hosted MCP server's
  # own client names its resource here, and the delegation exchange admits only
  # a subject grant whose audience equals it. Only an operator-provisioned
  # confidential client may front one, since the exchange authenticates it.
  def fronts?(resource)
    protected_resource.present? && protected_resource == resource
  end

  # Whether this client may use the delegation exchange: it fronts one of the
  # protected resources Fizzy is configured to issue grants for. Removing the
  # resource from FIZZY_OAUTH_MCP_RESOURCES turns its exchange off.
  def delegation_client?
    Oauth.mcp_resource?(protected_resource)
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

    # Reads the stored client_id: lock_client no longer reloads the row, so an
    # unsaved change to the issuer's client_id mustn't let it cascade.
    def refuse_to_destroy_personal_access
      if client_id_in_database == PERSONAL_ACCESS_CLIENT_ID
        errors.add :base, "The personal access token issuer can't be deleted"
        throw :abort
      end
    end

    def generate_client_secret
      self.raw_client_secret ||= Identity::AccessToken.generate_token(:client_secret)
      self.client_secret_digest = TokenDigester.digest(raw_client_secret)
    end

    def protected_resource_is_valid
      if protected_resource.present?
        if dynamically_registered? || !confidential?
          errors.add :protected_resource, "may only be set on an operator-provisioned confidential client"
        end

        if protected_resource.length > 255
          errors.add :protected_resource, "is too long"
        end
      end
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
