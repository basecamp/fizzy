class Api::BoardsController < Api::BaseController
  def index
    boards = Current.user.boards.alphabetically

    render json: boards.map { |board| board_json(board) }
  end

  def show
    board = Current.user.boards.find(params[:id])

    render json: board_json(board)
  end

  private
    def board_json(board)
      {
        id: board.id,
        name: board.name,
        all_access: board.all_access,
        created_at: board.created_at.iso8601,
        updated_at: board.updated_at.iso8601,
        creator: {
          id: board.creator.id,
          name: board.creator.name
        }
      }
    end
end

