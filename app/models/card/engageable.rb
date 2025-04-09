module Card::Engageable
  extend ActiveSupport::Concern

  STAGNATED_AFTER = 30.days

  included do
    has_one :engagement, dependent: :destroy, class_name: "Card::Engagement"

    scope :doing, -> { published.active.joins(:engagement) }
    scope :considering, -> { published.active.where.missing(:engagement) }

    scope :stagnated, -> { doing.where(last_active_at: ..STAGNATED_AFTER.ago) }
  end

  class_methods do
    def auto_reconsider_all_stagnated
      stagnated.find_each do |card|
        card.reconsider
      end
    end
  end

  def auto_reconsider_at
    last_active_at + STAGNATED_AFTER if last_active_at
  end

  def doing?
    active? && published? && engagement.present?
  end

  def considering?
    active? && published? && !doing?
  end

  def engage
    unless doing?
      transaction do
        reopen
        create_engagement!
      end
    end
  end

  def reconsider
    transaction do
      reopen
      engagement&.destroy
    end
  end
end
