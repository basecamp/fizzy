module FiltersHelper
  def filter_title(filter)
    if filter.collections.none?
      "All collections"
    elsif filter.collections.one?
      filter.collections.first.name
    else
      filter.collections.map(&:name).to_sentence
    end
  end

  def filter_chip_tag(text, params)
    link_to cards_path(params), class: "btn txt-small btn--remove fill-selected" do
      concat tag.span(text)
      concat icon_tag("close")
    end
  end

  def filter_hidden_field_tag(key, value)
    name = params[key].is_a?(Array) ? "#{key}[]" : key
    hidden_field_tag name, value, id: nil
  end

  def any_filters?(filter)
    filter.tags.any? || filter.assignees.any? || filter.creators.any? ||
    filter.stages.any? || filter.terms.any? ||
    filter.assignment_status.unassigned? || !filter.default_indexed_by?
  end
end
