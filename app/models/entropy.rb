class Entropy < ApplicationRecord
  belongs_to :container, polymorphic: true

  after_commit -> { container.cards.touch_all }
end
