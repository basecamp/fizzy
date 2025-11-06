class Public::Boards::ColumnsController < Public::BaseController
  before_action :set_column

  def show
    set_page_and_extract_portion_from @column.cards.active.latest.with_golden_first
  end

  private
    # Unlike the other public controllers, this is using params[:id] to fetch the column instead of the card
    def set_card
    end

    def set_column
      @column = @board.columns.find(params[:id])
    end
end
