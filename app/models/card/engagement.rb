class Card::Engagement < ApplicationRecord
  belongs_to :account, default: -> { card.account }
  belongs_to :card, class_name: "::Card", touch: true

  validates :status, presence: true, inclusion: { in: %w[doing on_deck] }
end
