module ClipboardHelper
  def button_to_copy_to_clipboard(url, &)
    tag.button class: "btn", data: {
      controller: "copy-to-clipboard tooltip", action: "copy-to-clipboard#copy",
      copy_to_clipboard_success_class: "btn--success", copy_to_clipboard_content_value: url
    }, &
  end
end
