module AccessesHelper
  def access_menu_tag(board, **options, &)
    tag.menu class: [ options[:class], { "toggler--toggled": board.all_access? } ], data: {
      controller: "filter toggle-class navigable-list",
      action: "keydown->navigable-list#navigate filter:changed->navigable-list#reset",
      navigable_list_focus_on_selection_value: true,
      navigable_list_actionable_items_value: true,
      toggle_class_toggle_class: "toggler--toggled" }, &
  end

  def access_toggles_for(users, selected:, disabled: false)
    render partial: "boards/access_toggle",
      collection: users, as: :user,
      locals: { selected: selected, disabled: disabled },
      cached: ->(user) { [ user, selected, disabled ] }
  end

  def access_involvement_advance_button(board, user, show_watchers: true, icon_only: false)
    access = board.access_for(user)

    turbo_frame_tag dom_id(board, :involvement_button) do
      concat board_watchers_list(board) if show_watchers
      concat involvement_button(board, access, show_watchers, icon_only)
    end
  end

  def board_watchers_list(board)
    watchers = board.watchers.with_avatars.load

    displayed_watchers = watchers.first(8)
    overflow_count = watchers.size - 8

    tag.div(class: "divider divider--fade") do
      tag.strong(watchers.any? ? "Watching for new cards" : "No one is watching for new cards", class: "txt-uppercase")
    end +
    tag.div(avatar_tags(displayed_watchers), class: "board-tools__watching") do
      tag.div(data: { controller: "dialog", action: "keydown.esc->dialog#close click@document->dialog#closeOnClickOutside" }) do
        tag.button("+#{overflow_count}", class: "overflow-count btn btn--circle borderless", data: { action: "dialog#open" }, aria: { label: "Show #{overflow_count} more watchers" }) +
        tag.dialog(avatar_tags(watchers), class: "board-tools__watching-dialog dialog panel", data: { dialog_target: "dialog" }, aria: { hidden: "true" })
      end if overflow_count > 0
    end
  end

  def involvement_button(board, access, show_watchers, icon_only)
    label_text = access.access_only? ? "Watch this" : "Stop watching"
    button_to(
      board_involvement_path(board), method: :put,
      params: { show_watchers: show_watchers, involvement: next_involvement(access.involvement), icon_only: icon_only },
      aria: { labelledby: dom_id(board, :involvement_label) },
      title: (label_text if icon_only),
      class: class_names("btn", { "btn--reversed": access.watching? && icon_only }),
      data: !icon_only && { bridge__overflow_menu_target: "item", bridge_title: label_text }) do
        icon_tag("notification-bell-#{icon_only ? 'reverse-' : nil}#{access.involvement.dasherize}") +
        tag.span(label_text, class: class_names("txt-nowrap txt-uppercase", "for-screen-reader": icon_only), id: dom_id(board, :involvement_label))
    end
  end

  private
    def next_involvement(involvement)
      order = %w[ watching access_only ]
      order[(order.index(involvement.to_s) + 1) % order.size]
    end
end
