class Card::BubbleUp < ApplicationRecord
  belongs_to :account, default: -> { card.account }
  belongs_to :card, touch: true

  scope :due_to_resurface, -> { joins(card: :not_now).where(resurface_at: ..Time.now) }

  def self.resurface_all_due
    due_to_resurface.find_each do |bubble_up|
      bubble_up.card.send_back_to_triage(skip_event: true)
    end
  end
end
