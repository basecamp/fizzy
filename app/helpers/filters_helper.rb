module FiltersHelper
  def bubble_filters_heading(filter, &)
    tag.h1 class: "txt-large flex align-center gap-half",
      style: filter.savable? ? "margin-inline-end: calc(var(--btn-size) / -2);" : "", &
  end

  def assignee_filter_text(filter)
    if filter.assignees.present?
      "assigned to #{filter.assignees.pluck(:name).to_choice_sentence}"
    elsif filter.assignments.unassigned?
      "assigned to no one"
    else
      "assigned to anyone"
    end
  end

  def tag_filter_text(filter)
    if filter.tags.present?
      filter.tags.map(&:hashtag).to_choice_sentence
    else
      "any tag"
    end
  end

  def filterable_users(filter)
    filter.bucket ? filter.bucket.users : filter.account.users
  end

  def filterable_tags(filter)
    filter.bucket ? filter.bucket.tags : filter.account.tags
  end
end
