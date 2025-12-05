class ApiToken < ApplicationRecord
  belongs_to :account
  belongs_to :user

  has_secure_token :token

  scope :active, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at IS NOT NULL AND expires_at <= ?", Time.current) }

  validates :name, presence: true, if: -> { name.present? }

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def active?
    !expired?
  end

  def touch_last_used_at!
    update_column(:last_used_at, Time.current)
  end
end
