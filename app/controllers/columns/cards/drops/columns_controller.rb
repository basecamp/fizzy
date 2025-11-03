class Columns::Cards::Drops::ColumnsController < ApplicationController
  include CardScoped

  def create
    @column = @card.collection.columns.find(params[:column_id])
    @card.triage_into(@column)
  end
end
