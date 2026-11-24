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
    # Makes sure the domain has a row, committed, before the transaction that
    # charges it: call it outside any transaction. A row created here and never
    # charged costs nothing, and the cleanup sweeps it once its window passes.
    #
    # Locking a row that may not exist yet deadlocks. Under REPEATABLE READ a
    # locking read of a missing row takes a gap lock every contender can hold
    # and none can insert past. Under READ COMMITTED, each creator that loses
    # to the unique index keeps a shared lock on the winner's row, and two of
    # them upgrading it deadlock. Committing the row first leaves .acquire one
    # lock to take, on a row that exists.
    def prepare(domain)
      create_or_find_by!(registrable_domain: domain) { |quota| quota.window_started_at = Time.current }
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound
      # A racing creator, or the cleanup, got there first; .acquire copes.
      nil
    end

    # The domain's row, locked; callers hold an open transaction, and the lock
    # serializes every same-domain creation behind it. Created here only when
    # .prepare's row is gone, deleted by the cleanup since, which is rare
    # enough to take the deadlock risk above, a retryable overload
    # (Resolver#create_client).
    #
    # That deletion has a window: .prepare finds an existing row without
    # touching it, so an expired one stays deletable until it's locked here.
    # It can't raise RecordNotFound, which bc3 retries on, because the locking
    # read is a find_by, and a row deleted before it reads nil and is created
    # again. Once it's read, the cleanup's DELETE waits for our transaction:
    # on our row lock on MySQL, on the writer lock our immediate transaction
    # holds on SQLite. Only an expired row is deletable, and an expired row is
    # no different from a missing one.
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

    # Only while the open tier is on, so an install that keeps it dark never
    # touches the table, from requests or from this job. Rows left from a time
    # it was on are inert once expired (see above), and swept once it's on
    # again.
    def cleanup
      if Oauth::Availability.cimd_open_registration_enabled?
        Oauth.cleanup_step(:cimd_domain_quotas) { expired.in_batches.delete_all }
      end
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
