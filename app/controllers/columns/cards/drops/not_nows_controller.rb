class Columns::Cards::Drops::NotNowsController < ApplicationController
  include CardScoped, ColumnFiltering

  def create
    @card.postpone
  end
end
