module BoardsHelper
  def link_back_to_board(board)
    safe_path = safe_return_to
    if safe_path
      path = safe_path
      label = params[:return_label].presence || board.name
    else
      path = board
      label = board.name
    end
    back_link_to(
      label,
      path,
      "keydown.left@document->hotkey#click keydown.esc@document->hotkey#click click->turbo-navigation#backIfSamePath"
    )
  end

  private

  def safe_return_to
    return unless params[:return_to].present?

    raw = params[:return_to].to_s

    # Only allow relative paths starting with a single "/"
    return unless raw.start_with?("/") && !raw.start_with?("//")

    uri = URI.parse(raw)

    # Prevent open redirect and non-HTTP schemes
    return unless uri.scheme.nil? && uri.host.nil?

    raw
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
