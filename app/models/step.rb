class Step < ApplicationRecord
  belongs_to :account, default: -> do
    # @type self: Step
    card.account
  end
  belongs_to :card, touch: true

  scope :completed, -> { where(completed: true) }

  validates :content, presence: true

  def completed?
    completed
  end
end
