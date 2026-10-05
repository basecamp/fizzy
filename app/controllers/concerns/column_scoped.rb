module ColumnScoped
  extend ActiveSupport::Concern

  include ArchivedBoardGuard

  included do
    before_action :set_column, :ensure_board_is_active
  end

  private
    def set_column
      @column = Current.user.accessible_columns.find(params[:column_id])
    end

    def guarded_board
      @column.board
    end
end
