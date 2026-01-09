# rbs_inline: enabled

module Board::Broadcastable
  extend ActiveSupport::Concern

  # @type self: singleton(Board) & singleton(Board::Broadcastable)
  # @type instance: Board & Board::Broadcastable

  included do
    broadcasts_refreshes
    broadcasts_refreshes_to ->(board) { [ board.account, :all_boards ] }
  end
end
