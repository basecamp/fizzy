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

  def allows?(method)
    method.in?(%w[ GET HEAD ]) || write?
  end

  def expired?
    expires_at? && expires_at.past?
  end

  def expires_in
    (expires_at - Time.current).to_i if expires_at?
  end

  def refresh!
    update! token: self.class.generate_unique_secure_token,
      refresh_token: self.class.generate_unique_secure_token,
      expires_at: EXPIRES_IN.from_now
  end

  private
    def set_expiry_and_refresh_token
      self.expires_at ||= EXPIRES_IN.from_now
      self.refresh_token ||= self.class.generate_unique_secure_token
    end
end
