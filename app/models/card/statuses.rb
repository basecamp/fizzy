module Card::Statuses
  extend ActiveSupport::Concern

  included do
    enum :status, %w[ creating drafted published ].index_by(&:itself)

    scope :published_or_drafted_by, ->(user) { where(status: :published).or(where(status: :drafted, creator: user)) }
  end

  class_methods do
    def remove_abandoned_creations
      Card.creating.where(updated_at: ..1.day.ago).destroy_all
    end
  end

  def can_recover_abandoned_creation?
    abandoned_creations.where(updated_at: 1.day.ago..).any?
  end

  def recover_abandoned_creation
    abandoned_creations.last.tap do |card|
      Card.creating.where(creator: creator).excluding(card).destroy_all
    end
  end

  def publish
    transaction do
      published!
      track_event :published
    end
  end

  private
    def abandoned_creations
      Card.creating.where(creator: creator).where("created_at != updated_at").excluding(self)
    end
end
