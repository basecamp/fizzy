module RichTextareaHelper
  def rich_textarea_toolbar(id = "editor-toolbar")
    content_tag("lexical-toolbar", id: id) do
      safe_join([
        # Inline formatting
        rich_textarea_toolbar_button("Bold", "bold"),
        rich_textarea_toolbar_button("Italic", "italic"),
        rich_textarea_toolbar_button("Link", "link"),

        # Block-level formatting
        rich_textarea_toolbar_button("Heading", "formatElement", data: { payload: "h2" }),
        rich_textarea_toolbar_button("Subheading", "formatElement", data: { payload: "h3" }),
        rich_textarea_toolbar_button("Code Block", "insertCodeBlock"),

        # Lists
        rich_textarea_toolbar_button("• Bullet List", "insertUnorderedList"),
        rich_textarea_toolbar_button("1. Numbered List", "insertOrderedList"),

        # Attachments
        rich_textarea_toolbar_button("Upload Attachment", "uploadAttachments")
      ])
    end
  end

  def rich_textarea_toolbar_button(label, command, data: {}, **properties)
    data[:command] = command
    content_tag(:button, label, type: "button", data: data, **properties)
  end
end
