class Public::Boards::ColumnsController < Public::BaseController
  before_action :set_column

  def show
    cards = if @board.manual_sorting_enabled?
      @column.cards.active.with_golden_first.ordered_by_position(last_active_at: :desc, id: :desc)
    else
      @column.cards.active.latest.with_golden_first
    end
    set_page_and_extract_portion_from cards
  end

  private
    # Unlike the other public controllers, this is using params[:id] to fetch the column instead of the card
    def set_card
    end

    def set_column
      @column = @board.columns.find(params[:id])
    end
end
