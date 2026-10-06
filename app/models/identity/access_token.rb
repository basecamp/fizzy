class Identity::AccessToken < ApplicationRecord
  belongs_to :identity
  belongs_to :oauth_client, class_name: "Oauth::Client", optional: true

  scope :personal, -> { where oauth_client_id: nil }
  scope :oauth, -> { where.not oauth_client_id: nil }

  has_secure_token
  enum :permission, %w[ read write ].index_by(&:itself), default: :read

  class << self
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
end
