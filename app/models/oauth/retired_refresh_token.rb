# A refresh token its grant has rotated away from. Presenting one again is
# either a client retrying a rotation whose response it lost, or someone
# replaying a stolen token (OAuth 2.1 §4.3.1). Within GRACE of the rotation,
# and only while the successor it produced is still the grant's current
# refresh token, it's a retry.
# Otherwise it's a replay, and the whole grant is revoked.
class Oauth::RetiredRefreshToken < ApplicationRecord
  # bc3's refresh_replay_grace default (Oauth::RefreshToken::Rotation).
  GRACE = 60.seconds

  # As long as a replay can still be recognized: past the idle limit, the
  # grant a retired token came from has lapsed unless it rotated since.
  RETENTION = Identity::AccessToken::REFRESH_IDLE_LIMIT

  # A retry is answered with the pair the rotation issued, which is stored
  # nowhere else in raw form. It's kept encrypted, sealed to expire with the
  # grace window, and blanked by the sweep soon after. The sweep looks back
  # this far, so it stays an index range over recent rows rather than a scan
  # of every retired token; anything older has long been unreadable anyway.
  SUCCESSOR_SWEEP_WINDOW = 1.day

  belongs_to :access_token, class_name: "Identity::AccessToken"

  scope :stale, -> { where(created_at: ...RETENTION.ago) }

  class << self
    def find_by_raw_token(raw)
      if raw.is_a?(String) && raw.present?
        find_by(refresh_token_digest: TokenDigester.digests(raw))
      end
    end

    def cleanup
      stale.in_batches.delete_all
    end

    def forget_successors
      where(created_at: SUCCESSOR_SWEEP_WINDOW.ago...GRACE.ago).where.not(successor_payload: nil).update_all(successor_payload: nil)
    end

    def successor_encryptor
      @successor_encryptor ||= ActiveSupport::MessageEncryptor.new \
        Rails.application.key_generator.generate_key("oauth_refresh_token_successor", 32)
    end
  end

  # The access and refresh token the rotation issued: { access_token:, refresh_token: }.
  def successor=(pair)
    self.successor_payload = self.class.successor_encryptor.encrypt_and_sign(pair.to_json, expires_in: GRACE, purpose: :oauth_refresh_token_successor)
  end

  # The pair, or nil once the grace window has passed or the sweep has
  # blanked it.
  def successor
    if successor_payload.present? && (decrypted = self.class.successor_encryptor.decrypt_and_verify(successor_payload, purpose: :oauth_refresh_token_successor))
      JSON.parse(decrypted).symbolize_keys.slice(:access_token, :refresh_token)
    end
  rescue ActiveSupport::MessageEncryptor::InvalidMessage, JSON::ParserError
    nil
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
    grant.refresh_token_digest != successor_refresh_token_digest
  end
end
