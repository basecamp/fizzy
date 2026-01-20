module FiltersHelper
  def filter_chip_tag(text, params)
    link_to cards_path(params), class: "btn txt-x-small btn--remove fill-selected flex-inline" do
      concat tag.span(text)
      concat icon_tag("close")
    end
  end

  def filter_hidden_field_tag(key, value)
    name = params[key].is_a?(Array) ? "#{key}[]" : key
    hidden_field_tag name, value, id: nil
  end

  def filter_selected_boards_title(user_filtering)
    user_filtering.selected_board_titles.collect { tag.strong it }.to_sentence.html_safe
  end

  def filter_place_menu_item(path, label, icon, new_window: false, current: false, turbo: true)
    link_to_params = {}
    link_to_params.merge!({ target: "_blank" }) if new_window
    link_to_params.merge!({ data: { turbo: false } }) unless turbo

    tag.li class: "popup__item", id: "filter-place-#{label.parameterize}", data: { filter_target: "item", navigable_list_target: "item" }, aria: { checked: current } do
      concat icon_tag(icon, class: "popup__icon")
      concat(link_to(path, link_to_params.merge(class: "popup__btn btn"), data: { turbo: turbo }) do
        concat tag.span(label, class: "overflow-ellipsis")
        concat icon_tag("check", class: "checked flex-item-justify-end", "aria-hidden": true)
      end)
    end
  end

  def filter_dialog(label, &block)
    tag.dialog class: "margin-block-start-half popup panel flex-column align-start gap-half fill-white shadow txt-small", data: {
      action: "turbo:before-cache@document->dialog#close keydown->navigable-list#navigate filter:changed->navigable-list#reset toggle->filter#filter",
      aria: { label: label, aria_description: label },
      controller: "navigable-list",
      dialog_target: "dialog",
      navigable_list_focus_on_selection_value: false,
      navigable_list_actionable_items_value: true
    }, &block
  end

  def filter_title(title)
    tag.strong title, class: "popup__title pad-inline-half", tabindex: "-1", data: { dialog_target: "focusTouch" }
  end

  def collapsible_nav_section(title, **properties, &block)
    tag.details class: "nav__section popup__section", data: { action: "toggle->nav-section-expander#toggle", nav_section_expander_target: "section", nav_section_expander_key_value: title.parameterize }, open: true, **properties do
      concat(tag.summary(class: "popup__section-title") do
        concat icon_tag "caret-down"
        concat title
      end)
      concat(tag.ul(class: "popup__list") do
        capture(&block)
      end)
    end
  end

  def filter_hotkey_link(title, path, key, icon)
    link_to path, class: "popup__item btn borderless", id: "filter-hotkey-#{key}", role: "listitem", data: { filter_target: "item", navigable_list_target: "item", controller: "hotkey", action: "keydown.#{key}@document->hotkey#click keydown.shift+#{key}@document->hotkey#click" } do
      concat icon_tag(icon)
      concat tag.span(title.html_safe)
      concat tag.kbd(key)
    end
  end

  def sorted_by_label(sort_value)
    case sort_value
    when "newest"
      "Newest to oldest"
    when "oldest"
      "Oldest to newest"
    when "latest"
      "Recently updated"
    else
      sort_value.humanize
    end
  end
end
