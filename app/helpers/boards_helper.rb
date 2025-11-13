module BoardsHelper
  def link_back_to_board(board)
    link_to board, class: "btn borderless txt-medium",
      data: { controller: "hotkey", action: "keydown.left@document->hotkey#click click->turbo-navigation#backIfSamePath" } do
        tag.span(tag.strong("Back to #{board.name}", class: "overflow-ellipsis") + tag.kbd("←", class: "txt-x-small margin-inline-start hide-on-touch"), class: "flex align-center").html_safe
    end
  end

  def link_to_edit_board(board)
    link_to edit_board_path(board), class: "btn", data: { controller: "tooltip" } do
      icon_tag("settings") + tag.span("Settings for #{board.name}", class: "for-screen-reader")
    end
  end
end
