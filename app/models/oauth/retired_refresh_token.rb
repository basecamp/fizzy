# A refresh token its grant has rotated away from. Presenting one again is
# either a client retrying a rotation whose response it lost, or someone
# replaying a stolen token (OAuth 2.1 §4.3.1). Within GRACE of the rotation,
# and only while the successor it produced is still the grant's current
# refresh token, it's a retry.
# Otherwise it's a replay, and the whole grant is revoked.
class Oauth::RetiredRefreshToken < ApplicationRecord
  # bc3's refresh_replay_grace default (Oauth::RefreshToken::Rotation).
  GRACE = 60.seconds

  # As long as a replay can still be recognized. It matches bc3's 90-day
  # refresh_token_ttl, after which a rotated token there has expired too.
  RETENTION = 90.days

  belongs_to :access_token, class_name: "Identity::AccessToken"

  scope :stale, -> { where(created_at: ...RETENTION.ago) }

  class << self
    def cleanup
      stale.in_batches.delete_all
    end
  end

  # Whether a replay now is a retry the grant can answer with the successor
  # this rotation produced. Pass the grant as just read: comparing against
  # that one read, rather than querying again, leaves no gap for a concurrent
  # rotation to slip into.
  def retryable?(grant)
    within_grace? && !superseded?(grant)
  end

  def within_grace?
    created_at > GRACE.ago
  end

  # The successor this rotation produced has been rotated in turn, so the
  # client demonstrably received it and moved on. This is read from the
  # grant's current token, never from timestamp order, which skewed host
  # clocks could invert.
  def superseded?(grant)
    grant.refresh_token != successor_refresh_token
  end
end
