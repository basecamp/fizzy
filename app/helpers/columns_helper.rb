module ColumnsHelper
  def button_to_set_column(card, column)
    button_to \
      tag.span(column.name, class: "overflow-ellipsis"),
      card_triage_path(card, column_id: column),
      method: :post,
      class: [ "card__column-name btn", { "card__column-name--current": column == card.column } ],
      form_class: "flex align-center gap-half",
      data: { turbo_frame: "_top" }
  end

  def column_frame_tag(id, src: nil, data: {}, **options, &block)
    data = data.reverse_merge \
      "drag-and-drop-refresh": true,
      controller: "frame",
      action: "turbo:before-frame-render->frame#morphRender turbo:before-morph-element->frame#morphReload"

    turbo_frame_tag(id, src: src, data: data, **options, &block)
  end
end
