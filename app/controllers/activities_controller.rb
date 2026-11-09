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
    @activities = Event.where(id: page_of_activity_ids).preloaded.reverse_chronologically
  end

  private
    # A reader's activities span all their boards, so the database sorts every match to keep
    # one page. Sorting whole rows means fetching each one first, which is most of this
    # request's time for a reader with a long history. Ids sort straight from the board,
    # action and created_at index, so page through ids, then load only that page's rows.
    def page_of_activity_ids
      @activity_ids = set_page_and_extract_portion_from(activities).ids
    end

    def activities
      Current.user.accessible_events
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
      if request.format.json? && @activity_ids.size == @page.records.limit_value
        uri = Addressable::URI.parse(request.url)
        uri.query_values = uri.query_values(Array).to_a.reject { |name, _| name == "page" } + [ [ "page", @page.next_param.to_s ] ]
        headers["Link"] = %(<#{uri}>; rel="next")
      end
    end
end
