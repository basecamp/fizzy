module Board::Burndownable
  extend ActiveSupport::Concern

  def burndown_data
    return nil unless sprint_configured?

    {
      start_date: start_date,
      end_date: end_date,
      available_hours: available_hours || 0,
      total_estimate: total_estimate,
      completed_estimate: completed_estimate,
      remaining_estimate: remaining_estimate,
      efficiency: efficiency_percentage,
      daily: daily_remaining,
      cards: sprint_cards_data
    }
  end

  def total_estimate
    cards.published.sum(:estimate_hours) || 0
  end

  def completed_estimate
    # Work completed = estimate - actual remaining
    total = 0
    cards.published.each do |card|
      if card.closed?
        total += card.estimate_hours || 0
      elsif card.remaining_hours.present? && card.estimate_hours.present?
        # Partial completion: estimate - remaining
        total += (card.estimate_hours - card.remaining_hours)
      end
    end
    total
  end

  def remaining_estimate
    # Sum of actual remaining hours (supports partial completion)
    cards.published.sum { |card| card.actual_remaining_hours }
  end

  def efficiency_percentage
    return 0 if available_hours.nil? || available_hours.zero?
    ((total_estimate / available_hours) * 100).round
  end

  def daily_remaining
    return [] unless sprint_configured?

    # Preload cards once
    published_cards = cards.published.preload(:closure)

    (start_date..end_date).map do |date|
      # Calculate remaining for this specific date
      daily_remaining = 0
      
      published_cards.each do |card|
        if card.closed? && card.closed_at && card.closed_at <= date.end_of_day
          # Card closed before/on this date → 0 remaining
          daily_remaining += 0
        elsif card.closed? && card.closed_at && card.closed_at > date.end_of_day
          # Card not yet closed on this date → use estimate
          daily_remaining += (card.estimate_hours || 0)
        else
          # Card open → use actual remaining or estimate
          daily_remaining += (card.remaining_hours || card.estimate_hours || 0)
        end
      end

      {
        date: date,
        remaining: daily_remaining,
        total: published_cards.sum { |c| c.estimate_hours || 0 },
        available: available_hours || 0
      }
    end
  end

  def sprint_cards_data
    cards.published.preload(:closure, :assignees).map do |card|
      {
        card: card,
        estimate_hours: card.estimate_hours,
        remaining_hours: card.remaining_hours,
        actual_remaining: card.actual_remaining_hours,
        completion_percentage: card.completion_percentage,
        business_value: card.business_value,
        difficulty: card.difficulty,
        closed: card.closed?,
        closed_at: card.closed_at
      }
    end
  end
end
