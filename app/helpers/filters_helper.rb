module FiltersHelper
  def bubble_filters_heading(filter, &)
    tag.h1 class: "txt-large flex align-center gap-half",
      style: token_list("margin-inline-end: calc(var(--btn-size) / -2);": filter.savable?), &
  end

  def buckets_filter_text(filter)
    if filter.buckets.any?
      filter.buckets.map(&:title).to_choice_sentence
    else
      "all projects"
    end
  end

  def assignments_filter_text(filter)
    if filter.assignees.present?
      "assigned to #{filter.assignees.pluck(:name).to_choice_sentence}"
    elsif filter.assignments.unassigned?
      "assigned to no one"
    else
      "assigned to anyone"
    end
  end

  def tags_filter_text(filter)
    if filter.tags.present?
      filter.tags.map(&:hashtag).to_choice_sentence
    else
      "any tag"
    end
  end
end
