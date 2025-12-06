module Board::StorageTracking
  extend ActiveSupport::Concern

  def bytes_used_changed(delta)
    increment!(:bytes_used, delta)
    account.adjust_storage_later(delta)
  end

  def recalculate_bytes_used
    update_columns bytes_used: count_bytes_used
  end

  private
    def count_bytes_used
      total_bytes = 0

      cards.with_rich_text_description_and_embeds.find_each do |card|
        total_bytes += card.bytes_used
        total_bytes += card.comments.with_rich_text_body_and_embeds.sum(&:bytes_used)
      end

      total_bytes
    end
end
