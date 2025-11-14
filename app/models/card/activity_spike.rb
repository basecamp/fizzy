class Card::ActivitySpike < ApplicationRecord
  belongs_to :account, default: -> { card.account }
  belongs_to :card, touch: true
end
