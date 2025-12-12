class Storage::Total < ApplicationRecord
  belongs_to :owner, polymorphic: true

  def pending_entries
    owner.storage_entries.pending(last_entry_id)
  end

  # Exact current usage (snapshot + pending)
  def current_usage
    bytes_stored + pending_entries.sum(:delta)
  end
end
