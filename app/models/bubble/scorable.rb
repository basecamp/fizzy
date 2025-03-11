module Bubble::Scorable
  extend ActiveSupport::Concern

  REFERENCE_DATE = Time.utc(2025, 1, 1)

  included do
    scope :ordered_by_activity, -> { order activity_score_order: :desc }
  end

  def rescore
    score = calculate_activity_score
    score_at = last_scorable_activity_at

    update! \
      activity_score: score,
      activity_score_at: score_at,
      activity_score_order: event_score_reference(score, score_at)
  end

  private
    def calculate_activity_score
      scorable_events.sum { |event| event_score(event) }
    end

    def event_score(event)
      days_ago = (last_scorable_activity_at - event.created_at) / 1.day
      event_weight(event) / (2**days_ago)
    end

    def event_weight(event)
      case
      when event.boosted? then 1
      when event.comment&.first_by_author_on_bubble? then 20
      when event.comment&.follows_comment_by_another_author? then 15
      when event.commented? then 10
      else 0
      end
    end

    def event_score_reference(score, activity_at)
      # The reference score is used to make the activity score comparable
      # across different bubbles, since it represents the bubble's activity
      # level at a consistent point in time.
      #
      # We store this as log2 to tame the huge/tiny numbers we'd otherwise get
      # when activity is far from the reference date.
      days_diff = (activity_at - REFERENCE_DATE) / 1.day
      Math.log2(1.0 + score) + days_diff
    end

    def last_scorable_activity_at
      scorable_events.maximum(:created_at) || created_at
    end

    def scorable_events
      events.where(action: [ :commented, :boosted ])
    end
end
