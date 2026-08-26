module Identity::Transferable
  extend ActiveSupport::Concern

  TRANSFER_LINK_EXPIRY_DURATION = 4.hours

  class_methods do
    # Redeems a transfer token: verifies and consumes it in one step, returning the
    # identity only when the token is authentic, unexpired, and still current. The
    # consume is single-use — a second redemption of the same token finds nothing to
    # consume and returns nil.
    def find_by_transfer_id(id)
      identity_id, generation = transfer_verifier.verified(id, purpose: :transfer)
      find_by(id: identity_id)&.consume_transfer_token(generation) if identity_id
    end

    def transfer_verifier
      Rails.application.message_verifier(:transfer)
    end
  end

  # Mints a transfer token bound to the current generation. This is a pure read: it
  # never mutates state, so rendering the link is safe to repeat. The TTL is a
  # backstop; single-use and revoke-on-regenerate come from the generation counter.
  def transfer_id
    self.class.transfer_verifier.generate \
      [ id, transfer_token_generation ], purpose: :transfer, expires_in: TRANSFER_LINK_EXPIRY_DURATION
  end

  # Revokes every outstanding transfer token by advancing the generation. Used when a
  # person asks for a fresh link — the previously issued ones stop verifying. The
  # increment is unconditional (keyed only on id), so it advances even from a stale
  # in-memory generation.
  def regenerate_transfer_token
    self.class.where(id: id).update_all("transfer_token_generation = transfer_token_generation + 1")
    reload
  end

  # Atomically consumes the presented generation. The UPDATE is conditional on that
  # generation — a compare-and-swap: exactly one caller can advance a given
  # generation, so a replay or a token from an already-superseded generation matches
  # no row and is rejected. This closes the redemption race (TOCTOU) without a lock.
  def consume_transfer_token(generation)
    consumed = self.class.where(id: id, transfer_token_generation: generation)
      .update_all("transfer_token_generation = transfer_token_generation + 1") == 1
    self if consumed
  end
end
