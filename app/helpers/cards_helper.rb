module CardsHelper
  def card_article_tag(card, id: dom_id(card, :article), **options, &block)
    classes = [
      options.delete(:class),
      ("golden-effect" if card.golden?),
      ("card--postponed" if card.postponed?),
      ("card--active" if card.active?),
      ("card--drafted" if card.drafted?)
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
      "in #{card.collection.name}"
    ]
    title << "assigned to #{card.assignees.map(&:name).to_sentence}" if card.assignees.any?
    title.join(" ")
  end
end
