# Enforce storage ledger integrity by preventing blob reuse in tracked contexts.
#
# Two invariants:
# 1. Account match: blob.account_id == record.account_id (multi-tenant safety)
# 2. No reuse within tracked contexts: a blob can only have one tracked attachment
#
# With per-attachment reconcile, blob reuse inside an account wouldn't break correctness -
# ledger would still count each attach, and reconcile would agree. However, we intentionally
# forbid reuse (except templates) as a product/control decision:
# - Simpler mental model (one blob = one attachment)
# - Prevents accidental quota manipulation via direct blob_id reuse
# - Cleaner audit trail in ledger entries
#
# Scope note: The no-reuse validation only blocks reuse when the *new* attachment is tracked
# AND only checks *existing* attachments in Storage::TRACKED_RECORD_TYPES. A blob first
# attached to an untracked type (avatar/export) could theoretically be reused in a tracked
# context. This is acceptable - user-accessible blob IDs from untracked contexts are
# basically nonexistent in practice.
#
# Exception: ActionText embeds are allowed to reuse blobs to support copy/paste.

ActiveSupport.on_load(:active_storage_attachment) do
  validate :blob_account_matches_record, on: :create
  validate :no_tracked_blob_reuse, on: :create

  private
    # Multi-tenant safety: blob must belong to same account as record
    # NOTE: Skips validation if record.account is nil. This is a theoretical bypass
    # if someone attaches before account assignment, but our flows assign account
    # before attachment. Global/unaccounted attachments (Identity/User avatars, exports)
    # bypass tenancy checks via try(:account) returning nil - this is intentional as
    # these classes don't participate in storage tracking.
    def blob_account_matches_record
      if record&.try(:account).present? && !whitelisted_for_cross_account?
        unless blob&.account_id == record.account.id
          errors.add(:blob_id, "blob account must match record account")
        end
      end
    end

    # Ledger integrity: blob can only have one tracked attachment
    def no_tracked_blob_reuse
      tracked_record = record&.try(:storage_tracked_record)
      if tracked_record.present? &&
          !whitelisted_for_cross_account? &&
          !(record_type == "ActionText::RichText" && name == "embeds")

        # Check for existing attachment of this blob in tracked contexts
        # Uses Storage::TRACKED_RECORD_TYPES constant to stay generic
        existing = ActiveStorage::Attachment
          .where(blob_id: blob_id)
          .where(record_type: Storage::TRACKED_RECORD_TYPES)
          .where.not(id: id)
          .exists?

        if existing
          errors.add(:blob_id, "cannot reuse blob in tracked storage context")
        end
      end
    end

    def whitelisted_for_cross_account?
      # Only template account blobs can be reused cross-tenant.
      # When TEMPLATE_ACCOUNT_ID is nil, no exemptions are granted.
      Storage::TEMPLATE_ACCOUNT_ID.present? && blob&.account_id == Storage::TEMPLATE_ACCOUNT_ID
    end
end
