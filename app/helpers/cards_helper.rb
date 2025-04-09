module CardsHelper
  CARD_ROTATION = %w[ 75 60 45 35 25 5 ]

  def card_title(card)
    card.title.presence || "Untitled"
  end

  def card_rotation(card)
    value = CARD_ROTATION[Zlib.crc32(card.to_param) % CARD_ROTATION.size]

    "--card-rotate: #{value}deg;"
  end

  def display_count_options
    CardsController::DISPLAY_COUNT_OPTIONS.map do |count|
      {
        value: count,
        label: count,
        selected: @display_count == count,
        id: "display-count-#{count}"
      }
    end
  end
end
