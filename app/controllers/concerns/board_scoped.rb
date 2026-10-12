module BoardScoped
  extend ActiveSupport::Concern

  include ArchivedBoardGuard

  included do
    before_action :set_board, :ensure_board_is_active
  end

  private
    def set_board
      @board = Current.user.boards.find(params[:board_id])
    end

    def ensure_permission_to_admin_board
      unless Current.user.can_administer_board?(@board)
        head :forbidden
      end
    end
end
