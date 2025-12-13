class Storage::Entry < ApplicationRecord
  belongs_to :account
  belongs_to :board, optional: true
  belongs_to :recordable, polymorphic: true, optional: true

  scope :pending, ->(last_entry_id) { where.not(id: ..last_entry_id) if last_entry_id }

  # Records may be destroyed (during cascading deletes) but .id still works.
  # Skip entirely if account is destroyed - no need to track storage for deleted accounts.
  # Skip materialize jobs for destroyed boards since there's nothing to update.
  def self.record(delta:, operation:, account:, board: nil, recordable: nil, blob: nil)
    return if delta.zero?
    return if account.destroyed?

    entry = create! \
      account_id: account.id,
      board_id: board&.id,
      recordable_type: recordable&.class&.name,
      recordable_id: recordable&.id,
      blob_id: blob&.id,
      delta: delta,
      operation: operation,
      user_id: Current.user&.id,
      request_id: Current.request_id

    account.materialize_storage_later
    board&.materialize_storage_later unless board&.destroyed?

    entry
  end
end
