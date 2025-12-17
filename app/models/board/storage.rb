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
    # Uses batched pluck queries to avoid loading huge ID arrays, and avoids
    # ActiveRecord model queries on ActiveStorage tables to sidestep cross-pool
    # issues when ActiveStorage uses separate connection pools (e.g., with replicas).
    def calculate_real_storage_bytes
      card_image_bytes + card_embed_bytes + comment_embed_bytes + board_embed_bytes
    end

    def card_image_bytes
      sum_blob_bytes_in_batches \
        ActiveStorage::Attachment.where(record_type: "Card", name: "image"),
        cards.pluck(:id)
    end

    def card_embed_bytes
      sum_embed_bytes_for "Card", cards.pluck(:id)
    end

    def comment_embed_bytes
      sum_embed_bytes_for "Comment", Comment.where(card_id: cards.pluck(:id)).pluck(:id)
    end

    def board_embed_bytes
      sum_embed_bytes_for "Board", [ id ]
    end

    def sum_embed_bytes_for(record_type, record_ids)
      rich_text_ids = ActionText::RichText \
        .where(record_type: record_type, record_id: record_ids)
        .pluck(:id)

      sum_blob_bytes_in_batches \
        ActiveStorage::Attachment.where(record_type: "ActionText::RichText", name: "embeds"),
        rich_text_ids
    end

    def sum_blob_bytes_in_batches(base_scope, record_ids)
      record_ids.each_slice(BATCH_SIZE).sum do |batch_ids|
        blob_ids = base_scope.where(record_id: batch_ids).pluck(:blob_id)
        ActiveStorage::Blob.where(id: blob_ids).sum(:byte_size)
      end
    end
end
