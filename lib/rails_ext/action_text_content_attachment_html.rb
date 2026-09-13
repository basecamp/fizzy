# ActionText::Attachables::ContentAttachment#to_html renders its nested content by handing the
# ActionText::Content object itself to render, so Action View derives the partial path from the
# object and then prefixes it with the rendering controller's namespace. Under a namespaced
# controller that asks for a partial nobody has (cards/action_text/contents/_content), and in a
# job — where Action Text falls back to an anonymous controller that has no path — the prefixing
# calls include? on nil. Name the partial so neither applies.
module ActionTextContentAttachmentHtml
  def to_html
    @to_html ||= content_instance.render \
      partial: content_instance.to_partial_path,
      object: content_instance,
      formats: :html
  end
end

ActiveSupport.on_load :action_text_content do
  ActionText::Attachables::ContentAttachment.prepend ActionTextContentAttachmentHtml
end
