class Board::Publication < ApplicationRecord
  belongs_to :board

  has_secure_token :key
end
