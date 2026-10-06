# A refresh token its grant has rotated away from. Presenting one again is
# either a client retrying a rotation whose response it lost, or someone
# replaying a stolen token (OAuth 2.1 §4.3.1). Within GRACE of the rotation,
# and only while the successor it produced is still current, it's a retry.
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

  def retryable?
    within_grace? && !superseded?
  end

  def within_grace?
    created_at > GRACE.ago
  end

  # The successor this rotation produced has been rotated in turn, so the
  # client demonstrably received it and moved on.
  def superseded?
    access_token.retired_refresh_tokens.where("created_at > ?", created_at).exists?
  end
end
