class Identity::AccessToken < ApplicationRecord
  EXPIRES_IN = 1.hour

  belongs_to :identity
  belongs_to :oauth_client, class_name: "Oauth::Client", optional: true

  scope :personal, -> { where oauth_client_id: nil }
  scope :oauth, -> { where.not oauth_client_id: nil }
  scope :active, -> { where(expires_at: nil).or(where(expires_at: Time.current..)) }

  has_secure_token
  enum :permission, %w[ read write ].index_by(&:itself), default: :read

  before_create :set_expiry_and_refresh_token, if: :oauth_client_id?

  class << self
    # The token a bearer request may authenticate with: active and honored.
    # Whether it permits the request's method is the caller's question.
    def find_honored(token)
      if (access_token = active.find_by(token: token)) && access_token.honored?
        access_token
      end
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

  # Rotates atomically on the presented refresh token, so a concurrent
  # rotation wins the row and the loser comes up empty-handed.
  def refresh(permission: self.permission)
    rotated = { token: self.class.generate_unique_secure_token,
      refresh_token: self.class.generate_unique_secure_token,
      expires_at: EXPIRES_IN.from_now, permission: permission, updated_at: Time.current }

    if self.class.where(id: id, refresh_token: refresh_token).update_all(rotated) == 1
      assign_attributes rotated
      true
    end
  end

  private
    def set_expiry_and_refresh_token
      self.expires_at ||= EXPIRES_IN.from_now
      self.refresh_token ||= self.class.generate_unique_secure_token
    end
end
