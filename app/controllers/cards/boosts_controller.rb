class Cards::BoostsController < ApplicationController
  include CardScoped

  def create
    count = if params[:boost_count].to_i == @card.boosts_count
      @card.boosts_count + 1
    else
      params[:boost_count].to_i
    end
    @card.boost!(count)
  end
end
