class Columns::RightPositionsController < ApplicationController
  include ColumnScoped

  def create
    @right_column = @column.right_column
    @column.move_right

    respond_to do |format|
      format.turbo_stream
      format.json { head :created }
    end
  end
end
