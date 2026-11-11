# Action Text rebuilds each attachment from the attributes it recognizes, and
# gets nil when a tag has none, such as <action-text-attachment gid="...">.
# Content#attachments then holds nil, and rendering the content raises.
# Keep the attachment as parsed, so it renders as a missing attachable.
module ActionTextContentUnrecognizedAttachments
  private
    def attachment_for_node(node, with_full_attributes: true)
      attachment = ActionText::Attachment.from_node(node)
      with_full_attributes ? attachment.with_full_attributes || attachment : attachment
    end
end

ActionText::Content.prepend ActionTextContentUnrecognizedAttachments
