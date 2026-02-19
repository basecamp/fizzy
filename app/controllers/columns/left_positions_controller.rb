class Columns::LeftPositionsController < ApplicationController
  include ColumnScoped

  def create
    @left_column = @column.left_column
    @column.move_left
    respond_to do |format|
      format.html
      format.turbo_stream
      format.json { head :no_content }
    end
  end
end
