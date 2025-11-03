module CollectionsHelper
  def link_back_to_collection(collection)
    link_to collection, class: "btn borderless txt-medium",
      data: { controller: "hotkey", action: "keydown.esc@document->hotkey#click click->turbo-navigation#backIfSamePath" } do
        tag.span ("&larr;" + tag.strong(collection.name, class: "overflow-ellipsis")).html_safe
    end
  end

  def link_to_edit_collection(collection)
    link_to edit_collection_path(collection), class: "btn", data: { controller: "tooltip" } do
      icon_tag("settings") + tag.span("Settings for #{collection.name}", class: "for-screen-reader")
    end
  end
end
