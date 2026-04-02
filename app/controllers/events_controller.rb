class EventsController < ApplicationController
  include DayTimelinesScoped

  API_ACTIONS = %w[
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
    respond_to do |format|
      format.html { fresh_when @day_timeline }
      format.json { set_page_and_extract_portion_from(api_events) }
    end
  end

  private
    def api_events
      Current.user.accessible_events
        .preloaded
        .where(action: API_ACTIONS)
        .for_creators(params[:creator_ids])
        .for_boards(params[:board_ids])
        .reverse_chronologically
    end
end
