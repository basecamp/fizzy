# Action Text renders a content attachment's inner content by handing the
# ActionText::Content object to the renderer, which resolves it as an object
# partial and so prefixes its path with the rendering controller's namespace
# (Cards::CommentsController looks for cards/action_text/contents/_content)
# and takes the request's formats (a JSON request finds no partial at all).
# Outside a request there is no controller prefix and Action View raises on nil.
# Render the partial by path, as Action Text does for the top-level content.
# Remove once rails/rails#58755 is in the Rails revision we run.
module ActionTextContentAttachmentRenderByPath
  def to_html
    @to_html ||= content_instance.render partial: content_instance.to_partial_path, formats: :html, locals: { content: content_instance }
  end
end

ActionText::Attachables::ContentAttachment.prepend ActionTextContentAttachmentRenderByPath
