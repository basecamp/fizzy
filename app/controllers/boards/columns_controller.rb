class Boards::ColumnsController < ApplicationController
  include BoardScoped

  before_action :set_column, only: %i[ show update destroy ]

  def index
    @columns = @board.columns.sorted
    fresh_when etag: @columns
  end

  def show
    cards = if @board.manual_sorting_enabled?
      @column.cards.active.with_golden_first.ordered_by_position(last_active_at: :desc, id: :desc).preloaded
    else
      @column.cards.active.latest.with_golden_first.preloaded
    end
    set_page_and_extract_portion_from cards
    fresh_when etag: @page.records
  end

  def create
    @column = @board.columns.create!(column_params)

    respond_to do |format|
      format.turbo_stream
      format.json { head :created, location: board_column_path(@board, @column, format: :json) }
    end
  end

  def update
    @column.update!(column_params)

    respond_to do |format|
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  def destroy
    @column.destroy

    respond_to do |format|
      format.html { redirect_back_or_to @board }
      format.json { head :no_content }
    end
  end

  private
    def set_column
      @column = @board.columns.find(params[:id])
    end

    def column_params
      params.expect(column: [ :name, :color ])
    end
end
