class Board::Archival < ApplicationRecord
  belongs_to :account, default: -> { board.account }
  belongs_to :board, touch: true
  belongs_to :user, optional: true
end
