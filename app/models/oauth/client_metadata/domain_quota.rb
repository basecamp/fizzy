# The open tier's registration quota: at most CAP clients per registrable domain
# (Oauth::ClientMetadata.registrable_domain) a WINDOW. Ported from bc3.
#
# Charged on creation, never on attempt: #reserve runs inside the transaction
# that creates the client, so a creation that rolls back (a lost race, an
# invalid row) refunds itself. A live window's row is never deleted, and a
# client deleted since keeps its charge: minting, deleting and minting again
# spends the same budget as minting.
#
# Once its window has elapsed a row is inert: .exhausted? reads false and the
# next #reserve starts a new window, so an expired row is no different from a
# missing one, and .cleanup deletes it. That keeps the table to the domains that
# registered within the last WINDOW, rather than every domain that ever did.
#
# .exhausted? is a preflight read, and fails open; #reserve holds the cap.
class Oauth::ClientMetadata::DomainQuota < ApplicationRecord
  self.table_name = "oauth_cimd_domain_quotas"

  CAP = 25
  WINDOW = 30.days

  # Attempts at locking a domain's row, each lost only to a row created or
  # deleted between our read and our write.
  ACQUIRE_ATTEMPTS = 3

  scope :expired, -> { where(window_started_at: ..WINDOW.ago) }

  class << self
    # The domain's row, locked, created if missing. Callers hold an open
    # transaction, and the lock serializes every same-domain creation behind it.
    #
    # Locks an existing row before trying to create one. Creating first would
    # leave every creator that lost to the unique index holding a shared lock
    # on the winner's row, and two of them upgrading it deadlock. Locking first
    # confines that to a domain's first registration, where a deadlock is a
    # retryable overload (Resolver#create_client); a creator that loses the
    # race reads the winner's row, locked.
    def acquire(domain)
      attempts = 0

      begin
        attempts += 1
        lock.find_by(registrable_domain: domain) || \
          transaction(requires_new: true) { create!(registrable_domain: domain, window_started_at: Time.current) }
      rescue ActiveRecord::RecordNotUnique
        attempts < ACQUIRE_ATTEMPTS ? retry : raise
      end
    end

    # Fails open: the reservation, not this read, holds the cap.
    def exhausted?(domain)
      find_by(registrable_domain: domain)&.exhausted? || false
    rescue StandardError
      false
    end

    def cleanup
      Oauth.cleanup_step(:cimd_domain_quotas) { expired.in_batches.delete_all }
    end
  end

  # Charges one creation to the window. Call only on a row from .acquire, inside
  # its transaction, so a rollback refunds it. False when the window is spent.
  def reserve
    if window_expired?
      update!(window_started_at: Time.current, created_count: 1)
      true
    elsif created_count >= CAP
      false
    else
      update!(created_count: created_count + 1)
      true
    end
  end

  # Spent, and still current: a capped row whose window has elapsed refuses
  # nothing.
  def exhausted?
    created_count >= CAP && !window_expired?
  end

  private
    def window_expired?
      window_started_at <= WINDOW.ago
    end
end
