class Storage::Entry < ApplicationRecord
  belongs_to :account
  belongs_to :board, optional: true
  belongs_to :recordable, polymorphic: true, optional: true

  scope :pending, ->(last_entry_id) { where.not(id: ..last_entry_id) if last_entry_id }

  # Accepts either objects or _id params (for after_destroy_commit snapshots)
  def self.record(delta:, operation:, account: nil, account_id: nil, board: nil, board_id: nil,
                   recordable: nil, recordable_type: nil, recordable_id: nil, blob: nil, blob_id: nil)
    return if delta.zero?

    account_id ||= account&.id
    board_id ||= board&.id
    blob_id ||= blob&.id

    entry = create! \
      account_id: account_id,
      board_id: board_id,
      recordable_type: recordable_type || recordable&.class&.name,
      recordable_id: recordable_id || recordable&.id,
      blob_id: blob_id,
      delta: delta,
      operation: operation,
      user_id: Current.user&.id,
      request_id: Current.request_id

    # Enqueue materialization - use find_by to handle cascading deletes
    # (Account/Board may be destroyed while attachments are still being cleaned up)
    Account.find_by(id: account_id)&.materialize_storage_later
    Board.find_by(id: board_id)&.materialize_storage_later if board_id

    entry
  end
end
