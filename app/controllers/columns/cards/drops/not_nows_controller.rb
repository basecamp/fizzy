class Columns::Cards::Drops::NotNowsController < ApplicationController
  include CardScoped

  def create
    @card.postpone
  end
end
