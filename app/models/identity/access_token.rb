class Identity::AccessToken < ApplicationRecord
  EXPIRES_IN = 1.hour

  # A grant whose refresh token goes unused this long lapses, and the client
  # must ask the user again. Each refresh restarts the clock, as each rotation
  # in bc3 mints a refresh token good for its 90-day refresh_token_ttl.
  REFRESH_IDLE_LIMIT = 90.days

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
  # A grant written without an expiry (by code from before idle expiry, while
  # a deploy rolls) is idle since its last write.
  scope :unlapsed, -> { where(refresh_token_expires_at: Time.current..).or(where(refresh_token_expires_at: nil, updated_at: REFRESH_IDLE_LIMIT.ago..)) }
  scope :lapsed, -> { oauth.where(refresh_token_expires_at: ...Time.current).or(oauth.where(refresh_token_expires_at: nil, updated_at: ...REFRESH_IDLE_LIMIT.ago)) }

  has_secure_token
  enum :permission, %w[ read write ].index_by(&:itself), default: :read

  before_create :set_expiry_and_refresh_token, if: :oauth_client_id?

  class << self
    def find_permissable(token, method:)
      if (access_token = active.find_by(token: token)) && access_token.honored? && access_token.allows?(method)
        access_token
      end
    end

    def cleanup
      lapsed.find_each(&:destroy)
    end

    def find_by_refresh_token(refresh_token)
      oauth.find_by(refresh_token: refresh_token)
    end

    # An authorization code redeems at most once (RFC 6749 §4.1.2): the grant it
    # mints is stamped with the code's jti, and the unique index refuses a second
    # stamp. A replay also revokes the grant the first redemption issued.
    def redeem(authorization_code, **attributes)
      create! authorization_code_jti: authorization_code.jti, **attributes
    rescue ActiveRecord::RecordNotUnique
      where(authorization_code_jti: authorization_code.jti).destroy_all
      nil
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
    oauth_client_id? && (refresh_token_expires_at || updated_at + REFRESH_IDLE_LIMIT).past?
  end

  # Rotates atomically on the presented refresh token, so a concurrent
  # rotation wins the row and the loser comes up empty-handed. A grant that
  # lapses mid-request doesn't rotate either, so a sweep that found it lapsed
  # never deletes a grant that was just renewed. The presented
  # token is retired, not forgotten, so presenting it again is recognized as
  # a retry or a replay (see Oauth::RetiredRefreshToken).
  def refresh(permission: self.permission)
    rotated = { token: self.class.generate_unique_secure_token,
      refresh_token: self.class.generate_unique_secure_token,
      expires_at: EXPIRES_IN.from_now, refresh_token_expires_at: REFRESH_IDLE_LIMIT.from_now,
      permission: permission, updated_at: Time.current }

    transaction do
      if self.class.unlapsed.where(id: id, refresh_token: refresh_token).update_all(rotated) == 1
        retired_refresh_tokens.create! refresh_token: refresh_token, successor_refresh_token: rotated[:refresh_token]
        assign_attributes rotated
        true
      end
    end
  end

  private
    def lock_grant
      self.class.lock.where(id: id).pluck(:id)
    end

    def set_expiry_and_refresh_token
      self.expires_at ||= EXPIRES_IN.from_now
      self.refresh_token ||= self.class.generate_unique_secure_token
      self.refresh_token_expires_at ||= REFRESH_IDLE_LIMIT.from_now
    end
end
