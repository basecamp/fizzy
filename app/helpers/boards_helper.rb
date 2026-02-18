module BoardsHelper
  def link_back_to_board(board)
    path = safe_return_to || board
    label = params[:return_label].presence || board.name
    back_link_to(
      label,
      path,
      "keydown.left@document->hotkey#click keydown.esc@document->hotkey#click click->turbo-navigation#backIfSamePath"
    )
  end

  private

  def safe_return_to
    return unless params[:return_to].present?

    uri = URI.parse(params[:return_to])
    return unless uri.host.nil? # prevents open redirect

    params[:return_to]
  rescue URI::InvalidURIError
    nil
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
