class Entropy < ApplicationRecord
  belongs_to :account, default: -> { container.account }
  belongs_to :container, polymorphic: true

  after_commit -> { container.cards.touch_all if container }
end
