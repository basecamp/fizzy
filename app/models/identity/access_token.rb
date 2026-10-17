class Identity::AccessToken < ApplicationRecord
  EXPIRES_IN = 1.hour

  # A grant whose refresh token goes unused this long lapses, and the client
  # must ask the user again. Each refresh restarts the clock, as each rotation
  # in bc3 mints a refresh token good for its 90-day refresh_token_ttl.
  #
  # The clock is updated_at. Only issuance and rotation write a grant, and
  # every rotation (this code's or any earlier version's) sets updated_at, so
  # no stored deadline can fall out of step with the token it governs.
  #
  # Fixed seconds, not calendar days: requests run in the browser's time zone,
  # where 90.days would shift by an hour across a daylight-saving change, and
  # the UTC sweep would then disagree with the token endpoint.
  REFRESH_IDLE_LIMIT = 90.days.in_seconds.seconds

  belongs_to :identity
  belongs_to :oauth_client, class_name: "Oauth::Client", optional: true
  has_many :retired_refresh_tokens, class_name: "Oauth::RetiredRefreshToken", dependent: :delete_all

  # Rotation locks the grant and then adds a retired token. Destroying takes
  # the same locks in the same order, grant first, so a refresh racing a
  # revocation waits rather than deadlocking against the retired-token delete.
  before_destroy :lock_grant, prepend: true

  scope :personal, -> { where oauth_client_id: nil }
  scope :oauth, -> { where.not oauth_client_id: nil }
  scope :active, -> { where(expires_at: nil).or(where(expires_at: Time.current..)) }
  scope :unlapsed, -> { where(updated_at: REFRESH_IDLE_LIMIT.ago..) }
  scope :lapsed, -> { oauth.where(updated_at: ...REFRESH_IDLE_LIMIT.ago) }

  # A prefix makes a token recognizable on sight, in logs, pastes and
  # repositories, and names its kind. Tokens issued before prefixes carry none
  # and keep working: every lookup matches the whole string. OAuth client
  # secrets are drawn here too (Oauth::Client), so every credential Fizzy
  # issues has one shape.
  PREFIXES = { personal: "fizzy_pat_", access: "fizzy_at_", refresh: "fizzy_rt_", client_secret: "fizzy_cs_" }

  # The base58 alphabet has_secure_token uses: no 0, O, I or l. Drawn through
  # Ruby's own SecureRandom, so it doesn't depend on ActiveSupport's base58
  # extension, which only has_secure_token loads.
  BASE58 = [ *"1".."9", *"A".."H", *"J".."N", *"P".."Z", *"a".."k", *"m".."z" ]

  # 44 base58 characters carry 257 bits, at least the 256 bits of randomness
  # bc3's tokens have (32 bytes). Tokens issued earlier are shorter and keep
  # working.
  BODY_LENGTH = 44

  enum :permission, %w[ read write ].index_by(&:itself), default: :read

  # Tokens are stored as digests (TokenDigester). The raw values exist only in
  # memory, on the record that issued or rotated them, to be handed to their
  # holder once. Personal access tokens also keep their plaintext in `token`
  # for now, because production code that reads only `token` shares this
  # database until this code is deployed there. OAuth access tokens never do.
  attribute :raw_token, :string
  attribute :raw_refresh_token, :string

  before_create :set_token
  before_create :set_expiry_and_refresh_token, if: :oauth_client_id?

  # Issuing or destroying a grant restarts its client's retention period
  # (Oauth::Client.cleanup). The touch waits until the grant's own transaction
  # commits. A revocation locks the grant, and touching the client in the same
  # transaction would then wait on the client's lock. A replayed code exchange
  # holds that lock while it waits on the grant, so the two would deadlock.
  after_commit :touch_oauth_client, on: %i[ create destroy ]

  # Every way a grant ends destroys it: disconnecting the app, revocation, the
  # idle-lapse sweep, a replayed refresh token or authorization code, and
  # deleting the client. So this is where the app's own plumbing ends
  # with it: push subscriptions its grants registered, which deliver to the
  # app's device or install, go once the identity holds no grant to the client.
  # Resources a grant set up for the account, like webhooks, are not plumbing,
  # and stay.
  #
  # Checked after commit, so when two grants to one client end at once,
  # whichever commits second finds none left.
  after_destroy_commit :end_app_plumbing, if: :oauth_client_id?

  class << self
    # The token a bearer request may authenticate with: active and honored.
    # Whether it permits the request's method is the caller's question.
    def find_honored(token)
      if (access_token = active.find_by_raw_token(token)) && access_token.honored?
        access_token
      end
    end

    # Finds the token within the current scope by its digest. A personal
    # access token written by code that stores only plaintext has no digest
    # yet, so it's found by plaintext and given one: no lookup but the first
    # ever matches on plaintext. Code that stores only plaintext issues
    # prefixed tokens too, so a prefix doesn't exempt a token from this.
    def find_by_raw_token(raw)
      if raw.is_a?(String) && raw.present?
        find_by(token_digest: TokenDigester.digests(raw)) || find_and_digest_undigested(raw)
      end
    end

    def find_by_refresh_token(raw)
      if raw.is_a?(String) && raw.present?
        oauth.find_by(refresh_token_digest: TokenDigester.digests(raw))
      end
    end

    def generate_token(kind)
      PREFIXES.fetch(kind) + SecureRandom.alphanumeric(BODY_LENGTH, chars: BASE58)
    end

    # Each grant is rechecked under its lock, so one renewed after it was
    # selected (by code from before idle expiry, mid-deploy, whose rotation
    # doesn't check for lapse) is spared.
    def cleanup
      lapsed.find_each do |grant|
        grant.with_lock { grant.destroy if grant.lapsed? }
      rescue ActiveRecord::RecordNotFound
        # Already gone.
      end
    end

    # An authorization code redeems at most once (RFC 6749 §4.1.2). Redeeming
    # records its jti (Oauth::RedeemedAuthorizationCode) in the same transaction
    # as the grant it mints, and the unique index refuses a second record. A
    # replay also revokes the grant the first redemption issued, and the record
    # outlives that grant, so a third attempt mints nothing either.
    def redeem(authorization_code, **attributes)
      transaction requires_new: true do
        Oauth::RedeemedAuthorizationCode.create! jti: authorization_code.jti
        create! authorization_code_jti: authorization_code.jti, **attributes
      end
    rescue ActiveRecord::RecordNotUnique
      where(authorization_code_jti: authorization_code.jti).destroy_all
      remember_redeemed authorization_code
      nil
    end

    private
      # A code redeemed before redemptions were recorded has a grant but no
      # record, and the failed transaction above rolled back the one it tried
      # to write. Write it now, so the code mints nothing once that grant is gone.
      def remember_redeemed(authorization_code)
        Oauth::RedeemedAuthorizationCode.create_or_find_by!(jti: authorization_code.jti)
      end

      # MySQL compares `token` case-insensitively, so a match is confirmed
      # byte for byte: a differently cased token neither authenticates nor
      # installs a digest that the real token would then never match.
      #
      # The digest goes to the primary even when the token was found on the
      # replica, as GET requests read. update_columns leaves updated_at alone.
      # A datacenter that can't reach the primary (Deployment::DatabaseResolver)
      # still authenticates the token and leaves the digest to one that can,
      # or to the backfill rerun.
      def find_and_digest_undigested(raw)
        personal.where(token_digest: nil, token: raw).detect { |candidate| candidate.token == raw }&.tap do |access_token|
          if Deployment::DatabaseResolver.in_primary_datacenter?
            ApplicationRecord.with_writing_role { access_token.update_columns token_digest: TokenDigester.digest(raw) }
          end
        end
      end
  end

  # OAuth tokens are honored only while OAuth acceptance is on (see
  # Oauth::Availability); personal tokens always are. The client is loaded only
  # when the server is dark and a pilot exemption might apply.
  def honored?
    oauth_client_id.nil? || Oauth::Availability.acceptance_enabled? || Oauth::Availability.acceptance_enabled?(oauth_client&.client_id)
  end

  def allows?(method)
    method.in?(%w[ GET HEAD ]) || write?
  end

  def expired?
    expires_at? && expires_at.past?
  end

  def expires_in
    (expires_at - Time.current).to_i if expires_at?
  end

  def lapsed?
    oauth_client_id? && (updated_at + REFRESH_IDLE_LIMIT).past?
  end

  # Rotates atomically on the presented refresh token, so a concurrent
  # rotation wins the row and the loser comes up empty-handed. A grant that
  # lapses mid-request doesn't rotate either, so a sweep that found it lapsed
  # never deletes a grant that was just renewed. The presented
  # token is retired, not forgotten, so presenting it again is recognized as
  # a retry or a replay (see Oauth::RetiredRefreshToken). The retired row
  # carries the new pair, encrypted, so a retry within the grace window can be
  # answered with it.
  def refresh(permission: self.permission)
    raw_token, raw_refresh_token = self.class.generate_token(:access), self.class.generate_token(:refresh)
    rotated = { token: nil, token_digest: TokenDigester.digest(raw_token),
      refresh_token_digest: TokenDigester.digest(raw_refresh_token),
      expires_at: EXPIRES_IN.from_now, permission: permission, updated_at: Time.current }

    transaction do
      if self.class.unlapsed.where(id: id, refresh_token_digest: refresh_token_digest).update_all(rotated) == 1
        retired_refresh_tokens.create! \
          refresh_token_digest: refresh_token_digest,
          successor_refresh_token_digest: rotated[:refresh_token_digest],
          successor: { access_token: raw_token, refresh_token: raw_refresh_token }
        assign_attributes rotated.merge(raw_token: raw_token, raw_refresh_token: raw_refresh_token)
        true
      end
    end
  end

  private
    def end_app_plumbing
      unless self.class.exists?(identity_id: identity_id, oauth_client_id: oauth_client_id)
        Push::Subscription.where(oauth_client_id: oauth_client_id, user: User.where(identity_id: identity_id)).delete_all
      end
    end

    def touch_oauth_client
      Oauth::Client.where(id: oauth_client_id).touch_all if oauth_client_id?
    end

    def lock_grant
      self.class.lock.where(id: id).pluck(:id)
    end

    # Personal access tokens are written in plaintext as well as digested,
    # for production code that reads only plaintext. An explicitly given
    # token is digested like a generated one.
    def set_token
      self.raw_token ||= token.presence || self.class.generate_token(oauth_client_id? ? :access : :personal)
      self.token_digest = TokenDigester.digest(raw_token)
      self.token = oauth_client_id? ? nil : raw_token
    end

    def set_expiry_and_refresh_token
      self.expires_at ||= EXPIRES_IN.from_now
      self.raw_refresh_token ||= self.class.generate_token(:refresh)
      self.refresh_token_digest = TokenDigester.digest(raw_refresh_token)
    end
end
