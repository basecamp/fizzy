# Archived boards are read-only: anything that would change them, their columns or their
# cards is refused until the board is unarchived.
module ArchivedBoardGuard
  extend ActiveSupport::Concern

  private
    def ensure_board_is_active
      if guarded_board&.archived? && !(request.get? || request.head?)
        head :forbidden
      end
    end

    def guarded_board
      @board
    end
end
