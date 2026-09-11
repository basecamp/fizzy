class Pin < ApplicationRecord
  belongs_to :account, default: -> { user.account }
  belongs_to :card
  belongs_to :user

  scope :ordered, -> { order(created_at: :desc, id: :desc) }

  # Cards move between boards, and a pin outlives a move to a board its owner cannot reach.
  # Only serve the pins whose owner still has access to the card's board.
  scope :accessible, -> { where(card: Card.joins(board: :accesses).where("accesses.user_id = pins.user_id")) }
end
