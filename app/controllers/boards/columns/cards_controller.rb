class Boards::Columns::CardsController < ApplicationController
  include BoardScoped

  before_action :set_column

  def index
    set_page_and_extract_portion_from @column.cards.active.latest.with_golden_first.preloaded
    fresh_when etag: @page.records

    respond_to do |format|
      format.json
    end
  end

  private
    def set_column
      @column = @board.columns.find(params[:column_id])
    end
end
