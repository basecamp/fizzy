class Board::Publication < ApplicationRecord
  belongs_to :account, default: -> { board.account }
  belongs_to :board

  has_secure_token :key
end
