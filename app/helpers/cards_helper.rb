module BubblesHelper
  BUBBLE_ROTATION = %w[ 75 60 45 35 25 5 ]

  def bubble_title(bubble)
    bubble.title.presence || "Untitled"
  end

  def bubble_rotation(bubble)
    value = BUBBLE_ROTATION[Zlib.crc32(bubble.to_param) % BUBBLE_ROTATION.size]

    "--bubble-rotate: #{value}deg;"
  end

  def display_count_options
    BubblesController::DISPLAY_COUNT_OPTIONS.map do |count|
      {
        value: count,
        label: count,
        selected: @display_count == count,
        id: "display-count-#{count}"
      }
    end
  end
end
