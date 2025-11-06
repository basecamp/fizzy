module CardsHelper
  def card_article_tag(card, id: dom_id(card, :article), **options, &block)
    classes = [
      options.delete(:class),
      ("golden-effect" if card.golden?),
      ("card--postponed" if card.postponed?),
      ("card--active" if card.active?)
    ].compact.join(" ")

    tag.article \
      id: id,
      style: "--card-color: #{card.color}; view-transition-name: #{id}",
      class: classes,
      **options,
      &block
  end

  def button_to_delete_card(card)
    button_to card_path(card),
        method: :delete, class: "btn txt-negative borderless txt-small", data: { turbo_frame: "_top", turbo_confirm: "Are you sure you want to permanently delete this card?" } do
      concat(icon_tag("trash"))
      concat(tag.span("Delete this card"))
    end
  end

  def card_title_tag(card)
    title = [
      card.title,
      "added by #{card.creator.name}",
      "in #{card.board.name}"
    ]
    title << "assigned to #{card.assignees.map(&:name).to_sentence}" if card.assignees.any?
    title.join(" ")
  end

  def card_social_tags(card)
    tag.meta(property: "og:title", content: "#{card.title} | #{card.board.name}") +
    tag.meta(property: "og:description", content: format_excerpt(@card&.description, length: 200)) +
    tag.meta(property: "og:image", content: @card.image.attached? ? "#{request.base_url}#{url_for(@card.image)}" : "#{request.base_url}/app-icon.png") +
    tag.meta(property: "og:url", content: card_url(@card))
  end

  def button_to_remove_card_image(card)
    button_to(card_image_path(card), method: :delete, class: "btn", data: { controller: "tooltip" }) do
      icon_tag("trash") + tag.span("Remove background image", class: "for-screen-reader")
    end
  end
end
