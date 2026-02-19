class Columns::RightPositionsController < ApplicationController
  include ColumnScoped

  def create
    @right_column = @column.right_column
    @column.move_right
    respond_to do |format|
      format.html
      format.turbo_stream
      format.json { head :no_content }
    end
  end
end
