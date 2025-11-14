class Card::Goldness < ApplicationRecord
  belongs_to :account, default: -> { card.account }
  belongs_to :card, touch: true
end
