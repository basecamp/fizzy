class Identity::Transfer < ApplicationRecord
  EXPIRATION_TIME = 4.hours

  belongs_to :identity

  has_secure_token

  scope :active, -> { where(created_at: EXPIRATION_TIME.ago..) }
  scope :stale,  -> { where(created_at: ...EXPIRATION_TIME.ago) }

  class << self
    def consume(token)
      active.find_by(token: token)&.consume
    end

    def cleanup
      stale.delete_all
    end
  end

  def consume
    self if self.class.where(id: id).delete_all == 1
  end
end
