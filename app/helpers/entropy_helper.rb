module EntropyHelper
  def entropy_auto_close_options
    [ 3, 7, 30, 90, 365, 11 ]
  end

  def entropy_bubble_options_for(card)
    {
      daysBeforeReminder: card.entropy.days_before_reminder,
      closesAt: card.entropy.auto_clean_at.iso8601,
      action: "Closes"
    }
  end

  def stalled_bubble_options_for(card)
    if card.last_activity_spike_at
      {
        stalledAfterDays: card.entropy.days_before_reminder,
        lastActivitySpikeAt: card.last_activity_spike_at.iso8601,
        updatedAt: card.updated_at.iso8601,
        action: "Stalled"
      }
    end
  end
end
