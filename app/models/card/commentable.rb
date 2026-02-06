module Card::Commentable
  extend ActiveSupport::Concern

  included do
    has_many :comments, dependent: :destroy
  end

  def commentable?
    published?
  end

  private
    STORAGE_BATCH_SIZE = 1000

    # Override to include comments, but only load comments that have attachments.
    # Cards can have thousands of comments; most won't have attachments.
    # Streams in batches to avoid loading all IDs into memory at once.
    def storage_transfer_records
      comment_ids_with_attachments = storage_comment_ids_with_attachments

      if comment_ids_with_attachments.any?
        [ self, *comments.where(id: comment_ids_with_attachments).to_a ]
      else
        [ self ]
      end
    end

    def storage_comment_ids_with_attachments
      direct = []
      rich_text_map = {}

      # Stream comment IDs in batches to avoid loading all into memory
      comments.in_batches(of: STORAGE_BATCH_SIZE) do |batch|
        batch_ids = batch.pluck(:id)

        direct.concat \
          ActiveStorage::Attachment
            .where(record_type: "Comment", record_id: batch_ids)
            .distinct
            .pluck(:record_id)

        ActionText::RichText
          .where(record_type: "Comment", record_id: batch_ids)
          .pluck(:id, :record_id)
          .each { |rt_id, comment_id| rich_text_map[rt_id] = comment_id }
      end

      embed_comment_ids = if rich_text_map.any?
        rich_text_map.keys.each_slice(STORAGE_BATCH_SIZE).flat_map do |batch_ids|
          ActiveStorage::Attachment
            .where(record_type: "ActionText::RichText", record_id: batch_ids)
            .distinct
            .pluck(:record_id)
        end.filter_map { |rt_id| rich_text_map[rt_id] }
      else
        []
      end

      (direct + embed_comment_ids).uniq
    end
end
