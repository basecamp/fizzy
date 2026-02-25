module ColumnsHelper
  def button_to_set_column(card, column)
    button_to \
      tag.span(column.name, class: "overflow-ellipsis"),
      card_triage_path(card, column_id: column),
      method: :post,
      class: [ "card__column-name btn", { "card__column-name--current": column == card.column && card.open? } ],
      disabled: column == card.column && card.open?,
      style: "--column-color: #{column.color}",
      form_class: "flex gap-half",
      data: { turbo_frame: "_top", scroll_to_target: column == card.column && card.open? ? "target" : nil }
  end

  def column_tag(id:, name:, drop_url:, collapsed: true, selected: nil, card_color: "var(--color-card-default)", data: {}, **properties, &block)
    classes = token_list("cards", properties.delete(:class), "is-collapsed": collapsed, "is-expanded": !collapsed)
    hotkeys_disabled = data[:card_hotkeys_disabled]

    data = {
      drag_and_drop_target: "container",
      navigable_list_target: "item",
      column_name: name,
      drag_and_drop_url: drop_url,
      drag_and_drop_css_variable_name: "--card-color",
      drag_and_drop_css_variable_value: card_color
    }.merge(data)

    data[:action] = token_list(
      "turbo:before-morph-attribute->collapsible-columns#preventToggle",
      "focus->navigable-list#select",
      data.delete(:action)
    )

    tag.section(id: id, class: classes, tabindex: "0", "aria-selected": selected, data: data, **properties) do
      tag.div(class: "cards__transition-container", data: {
        controller: "navigable-list css-variable-counter",
        css_variable_counter_property_name_value: "--card-count",
        navigable_list_supports_horizontal_navigation_value: "false",
        navigable_list_prevent_handled_keys_value: "true",
        navigable_list_auto_select_value: "false",
        navigable_list_actionable_items_value: "true",
        navigable_list_only_act_on_focused_items_value: "true",
        card_hotkeys_disabled: hotkeys_disabled,
        action: "keydown->navigable-list#navigate"
      }, &block)
    end
  end

  def column_frame_tag(id, src: nil, data: {}, **options, &block)
    data = data.with_defaults \
      drag_and_drop_refresh: true,
      controller: "frame",
      action: "turbo:before-frame-render->frame#morphRender turbo:before-morph-element->frame#morphReload"
    options[:refresh] = :morph if src.present?
    turbo_frame_tag(id, src: src, data: data, **options, &block)
  end
end
