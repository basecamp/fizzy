module Storage
  def self.table_name_prefix
    "storage_"
  end

  # Record types that participate in storage tracking (ledger entries created on attach).
  # The no-reuse validation uses this to scope its check.
  #
  # IMPORTANT: Update this constant when adding tracked attachments to new models.
  # If you add a direct attachment (not via RichText embeds) to Comment, Board, or
  # another model with Storage::Tracked, you must add its record_type here or the
  # no-reuse validation won't protect it.
  TRACKED_RECORD_TYPES = %w[Card ActionText::RichText].freeze

  # Account ID for template/demo blobs that can be reused cross-tenant.
  # Set to nil to disable the whitelist (no exemptions).
  TEMPLATE_ACCOUNT_ID = nil
end
