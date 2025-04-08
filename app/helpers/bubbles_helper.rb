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

  def bubbles_next_page_link(target, page:, filter:, fetch_on_visible: false, data: {}, **options)
    url = previews_bubbles_path(target: target, page: page.next_param, **filter.as_params)

    if fetch_on_visible
      data[:controller] = "#{data[:controller]} fetch-on-visible"
      data[:fetch_on_visible_url_value] = url
    end

    link_to "Load more",
      url,
      id: "#{target}-load-page-#{page.next_param}",
      data: { turbo_stream: true, **data },
      class: "btn txt-small",
      **options
  end
end
