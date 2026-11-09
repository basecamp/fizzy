module ActivitiesHelper
  def activity_cache_key(event)
    [ event, event.eventable, event.card, event.board, event.creator, *assignment_cache_key(event) ]
  end

  private
    # Assignments are worded for the viewer: "will handle", "yourself".
    def assignment_cache_key(event)
      if event.action.card_assigned? || event.action.card_unassigned?
        [ Current.user, *event.assignees ]
      end
    end
end
