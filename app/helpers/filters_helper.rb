module FiltersHelper
  def bubble_filters_heading(view, &)
    tag.h1 class: "txt-large flex align-center gap-half",
      style: view.bucket_default? ? "" : "margin-inline-end: calc(var(--btn-size) / -2);", &
  end

  def assignee_filter_text(view)
    if view.assignees.present?
      "assigned to #{view.assignees.pluck(:name).to_choice_sentence}"
    elsif view.assignment.unassigned?
      "assigned to no one"
    else
      "assigned to anyone"
    end
  end

  def tag_filter_text(view)
    if view.tags.present?
      view.tags.map(&:hashtag).to_choice_sentence
    else
      "any tag"
    end
  end

  def filterable_users(view)
    view.bucket ? view.bucket.users : view.account.users
  end

  def filterable_tags(view)
    view.bucket ? view.bucket.tags : view.account.tags
  end

  # `#view_filter_params` is memoized to avoid spam in logs about unpermitted params
  def view_filter_params(view = nil)
    @view_filter_params ||= if view
      view.to_params
    else
      params.permit(*View::KNOWN_FILTERS)
    end
  end
end
