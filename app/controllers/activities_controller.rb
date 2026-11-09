class ActivitiesController < ApplicationController
  ACTIONS = %w[
    card_assigned
    card_auto_postponed
    card_board_changed
    card_closed
    card_postponed
    card_published
    card_reopened
    card_sent_back_to_triage
    card_title_changed
    card_triaged
    card_unassigned
    comment_created
  ].freeze

  def index
    set_page_and_extract_portion_from(activities)
  end

  private
    def activities
      Current.user.accessible_events
        .preloaded
        .where(action: ACTIONS)
        .for_creators(params[:creator_ids])
        .for_boards(params[:board_ids])
        .reverse_chronologically
    end

    # geared_pagination's X-Total-Count, and its check for the last page, count every event
    # the reader can see, on every request. Pollers re-read the first page all day, and the
    # API documents only the Link header, so send that alone and judge it from the page: a
    # full page links on, at worst to one empty page. Query pairs stay pairs, so repeated
    # filters like creator_ids[] survive into the link.
    def set_paginated_headers
      if request.format.json? && @page.records.size == @page.records.limit_value
        uri = Addressable::URI.parse(request.url)
        uri.query_values = uri.query_values(Array).to_a.reject { |name, _| name == "page" } + [ [ "page", @page.next_param.to_s ] ]
        headers["Link"] = %(<#{uri}>; rel="next")
      end
    end
end
