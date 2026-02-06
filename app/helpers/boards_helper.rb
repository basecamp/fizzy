module BoardsHelper
  def link_back_to_board(board)
    back_link_to board.name, board, "keydown.left@document->hotkey#click keydown.esc@document->hotkey#click click->turbo-navigation#backIfSamePath"
  end

  def link_to_edit_board(board)
    link_to edit_board_path(board), class: "btn btn--circle-mobile",
      data: { controller: "tooltip", bridge__overflow_menu_target: "item", bridge_title: "Board settings" } do
      icon_tag("settings") + tag.span("Settings for #{board.name}", class: "for-screen-reader")
    end
  end

  def bridged_button_to_board(board)
    link_to "Go to #{board.name}", board, hidden: true, data: {
      bridge__buttons_target: "button",
      bridge_icon_url: bridge_icon("board"),
      bridge_title: "Go to #{board.name}"
    }
  end
end
