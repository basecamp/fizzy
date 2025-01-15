module FiltersHelper
  def filter_chip_tag(text, params)
    link_to bubbles_path(params), class: "btn txt-small btn--remove" do
      concat tag.span(text)
      concat image_tag("close.svg", aria: { hidden: true }, size: 24)
    end
  end

  def filter_hidden_field_tag(key, value)
    name = params[key].is_a?(Array) ? "#{key}[]" : key
    hidden_field_tag name, value, id: nil
  end

  def divider_update_path(filter)
    if filter.persisted?
      filter_path(filter)
    elsif filter.buckets.one?
      bucket_bubble_limit_path(filter.buckets.first)
    end
  end

  def divider_update_method(filter)
    if filter.persisted? || filter.buckets.one?
      :patch
    else
      :get
    end
  end
end
