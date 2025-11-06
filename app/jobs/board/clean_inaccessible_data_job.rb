class Board::CleanInaccessibleDataJob < ApplicationJob
  def perform(user, board)
    board.clean_inaccessible_data_for(user)
  end
end
