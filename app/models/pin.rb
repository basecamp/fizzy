class Pin < ApplicationRecord
  belongs_to :account, default: -> do
    # @type self: Pin
    user.account
  end
  belongs_to :card
  belongs_to :user

  scope :ordered, -> { order(created_at: :desc) }
end
