module AccessesHelper
  MAX_DISPLAYED_WATCHERS = 8

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
      cached: ->(user) { [ user, selected ] }
  end

  def access_involvement_advance_button(board, user, show_watchers: true, icon_only: false)
    access = board.access_for(user)

    turbo_frame_tag dom_id(board, :involvement_button) do
      concat board_watchers_list(board) if show_watchers
      concat involvement_button(board, access, show_watchers, icon_only)
    end
  end

  def board_watchers_list(board)
    watchers = board.watchers

    displayed_watchers = watchers.limit(MAX_DISPLAYED_WATCHERS)
    overflow_count = watchers.count - MAX_DISPLAYED_WATCHERS

    safe_join([
      tag.strong(displayed_watchers.any? ? "Watching for new cards" : "No one is watching for new cards", class: "txt-uppercase"),
      tag.div(class: "board-tools__watching") do
        safe_join([
          safe_join(displayed_watchers.map { |watcher| avatar_tag(watcher) }),
          (tag.div(data: { controller: "dialog", action: "keydown.esc->dialog#close click@document->dialog#closeOnClickOutside" }) do
            concat tag.button("+#{overflow_count}", class: "overflow-count btn btn--circle borderless", data: { action: "dialog#open" }, aria: { label: "Show #{overflow_count} more watchers" })
            concat(tag.dialog(class: "board-tools__watching-dialog dialog panel", data: { dialog_target: "dialog" }, aria: { hidden: "true" }) do
              safe_join(watchers.map { |watcher| avatar_tag(watcher) })
            end)
          end if overflow_count > 0)
        ].compact)
      end
    ])
  end

  def involvement_button(board, access, show_watchers, icon_only)
    involvement_label_id = dom_id(board, :involvement_label)

    button_to(
      board_involvement_path(board),
      method: :put,
      aria: { labelledby: involvement_label_id },
      class: class_names("btn", { "btn--reversed": access.watching? && icon_only }),
      params: { show_watchers: show_watchers, involvement: next_involvement(access.involvement), icon_only: icon_only }
    ) do
      safe_join([
        icon_tag("notification-bell-#{icon_only ? 'reverse-' : nil}#{access.involvement.dasherize}"),
        tag.span(
          involvement_access_label(access),
          class: class_names("txt-nowrap txt-uppercase", "for-screen-reader": icon_only),
          id: involvement_label_id
        )
      ])
    end
  end

  private
    def next_involvement(involvement)
      order = %w[ watching access_only ]
      order[(order.index(involvement.to_s) + 1) % order.size]
    end

    def involvement_access_label(access)
      if access.access_only?
        "Watch this"
      else
        "Stop watching"
      end
    end
end
