module Board::Storage
  extend ActiveSupport::Concern
  include Storage::Totaled

  # Board's own embeds (public_description) count toward itself
  def board_for_storage_tracking
    self
  end

  private
    BATCH_SIZE = 1000

    # Calculate actual storage by summing blob sizes.
    #
    # Storage tracking is a business abstraction - we count what users upload.
    # Original upload bytes only; variants/previews/derivatives excluded.
    # Physical storage optimizations (deduplication, compression) don't affect quotas.
    def calculate_real_storage_bytes
      @card_ids = nil  # Clear memoization for fresh calculation
      card_image_bytes + card_embed_bytes + comment_embed_bytes + board_embed_bytes
    end

    def card_ids
      @card_ids ||= cards.ids
    end

    def card_image_bytes
      sum_blob_bytes_in_batches \
        ActiveStorage::Attachment.where(record_type: "Card", name: "image"),
        card_ids
    end

    def card_embed_bytes
      sum_embed_bytes_for "Card", card_ids
    end

    def comment_embed_bytes
      card_ids.each_slice(BATCH_SIZE).sum do |batch|
        sum_embed_bytes_for "Comment", Comment.where(card_id: batch).ids
      end
    end

    def board_embed_bytes
      sum_embed_bytes_for "Board", [ id ]
    end

    def sum_embed_bytes_for(record_type, record_ids)
      rich_text_ids = ActionText::RichText \
        .where(record_type: record_type, record_id: record_ids).ids

      sum_blob_bytes_in_batches \
        ActiveStorage::Attachment.where(record_type: "ActionText::RichText", name: "embeds"),
        rich_text_ids
    end

    def sum_blob_bytes_in_batches(base_scope, record_ids)
      # Count per-attachment to match ledger model.
      # Same blob attached 3 times = 3x bytes (business abstraction, not physical storage).
      #
      # Do NOT remove the join thinking it's a performance optimization - it's required
      # for correct per-attachment counting. We keep ActiveStorage/ActionText in the same
      # database (realm/geo partitioning, not functionality partitioning), so cross-table
      # joins are fine.
      record_ids.each_slice(BATCH_SIZE).sum do |batch_ids|
        base_scope
          .where(record_id: batch_ids)
          .joins(:blob)
          .sum("active_storage_blobs.byte_size")
      end
    end
end
