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
    @activities = activities.preloaded.where(id: @page.records.ids)
  end

  private
    def activities
      Current.user.accessible_events
        .where(action: ACTIONS)
        .for_creators(params[:creator_ids])
        .for_boards(params[:board_ids])
        .reverse_chronologically
    end
end
