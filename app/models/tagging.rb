class Tagging < ApplicationRecord
  belongs_to :account, default: -> do
    # @type self: Tagging
    card.account
  end
  belongs_to :tag
  belongs_to :card, touch: true
end
