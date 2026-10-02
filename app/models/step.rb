class Step < ApplicationRecord
  belongs_to :account, default: -> { card.account }
  belongs_to :card

  after_save    -> { card.touch_last_active_at }
  after_destroy -> { card.touch_last_active_at unless destroyed_by_association }

  scope :completed, -> { where(completed: true) }

  validates :content, presence: true

  def completed?
    completed
  end
end
