class Columns::Cards::Drops::ClosuresController < ApplicationController
  include CardScoped

  def create
    @card.close
  end
end
