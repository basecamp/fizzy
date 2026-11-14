class Columns::Cards::Drops::ClosuresController < ApplicationController
  include CardScoped, ColumnFiltering

  def create
    @card.close
  end
end
