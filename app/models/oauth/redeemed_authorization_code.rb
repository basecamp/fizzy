# An authorization code that has been redeemed, by its jti. Codes are
# stateless, and the grant a code minted carries its jti too, but that grant
# can be destroyed: by a replay of the code, by revocation, by disconnecting
# the app. This record outlives it, so the code still can't be redeemed again
# for as long as it could otherwise be presented (RFC 6749 §4.1.2; rubric
# GP-4, GP-5).
class Oauth::RedeemedAuthorizationCode < ApplicationRecord
  # Well past the code's 60-second lifetime, as the rubric asks (24 hours past
  # expiry), so a skewed clock or a slow replay is still recognized.
  RETENTION = 25.hours

  scope :stale, -> { where(created_at: ...RETENTION.ago) }

  def self.cleanup
    stale.in_batches.delete_all
  end
end
