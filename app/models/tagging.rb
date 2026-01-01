class Tagging < ApplicationRecord
  belongs_to :account, default: -> { card.account }
  belongs_to :tag
  belongs_to :card, touch: true
end
