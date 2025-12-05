module ActionTextContentStorageTracking
  def bytes_used
    attachables.sum { |attachable| attachable.try(:byte_size) || 0 }
  end
end

module ActionTextRichTextStorageTracking
  def bytes_used
    body&.bytes_used || 0
  end
end

ActiveSupport.on_load :action_text_content do
  include ActionTextContentStorageTracking
end

ActiveSupport.on_load :action_text_rich_text do
  include ActionTextRichTextStorageTracking
end
