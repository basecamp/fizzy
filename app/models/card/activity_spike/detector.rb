class Card::ActivitySpike::Detector
  attr_reader :card

  def initialize(card)
    @card = card
  end

  def detect
    if has_activity_spike?
      register_activity_spike
      true
    else
      false
    end
  end

  private
    def has_activity_spike?
      card.entropic? && (multiple_people_commented? || card_was_just_assigned? || card_was_just_reopened?)
    end

    def register_activity_spike
      Card.suppressing_turbo_broadcasts do
        Card::ActivitySpike.find_or_create_by!(card: card).touch
      end
    end

    def multiple_people_commented?(minimum_comments: 3, minimum_participants: 2)
      card.comments
        .where(created_at: recent_period.seconds.ago..)
        .group(:card_id)
        .having("COUNT(*) >= ?", minimum_comments)
        .having("COUNT(DISTINCT creator_id) >= ?", minimum_participants)
        .exists?
    end

    def recent_period
      card.entropy.auto_clean_period * 0.33
    end

    def card_was_just_assigned?
      card.assigned? && card_was_just?(:assigned)
    end

    def card_was_just_reopened?
      card.open? && card_was_just?(:reopened)
    end

    def card_was_just?(action)
      last_event&.action&.to_s == "card_#{action}" && last_event.created_at > 1.minute.ago
    end

    def last_event
      card.events.order(:created_at).last
    end
end
