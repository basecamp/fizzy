module ActivitiesHelper
  # An activity embeds its card or comment, board and creator as they are now,
  # and words assignments for the viewer ("will handle", "yourself"), so its
  # fragment is keyed on all of those, not on the event alone. Loading the
  # assignees here also serves the description, which reads the same records.
  def activity_cache_key(event)
    [ event, event.eventable, event.card, event.board, event.creator, *assignment_cache_key(event) ]
  end

  private
    def assignment_cache_key(event)
      if event.action.card_assigned? || event.action.card_unassigned?
        [ Current.user, *event.assignees ]
      end
    end
end
