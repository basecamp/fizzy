# rbs_inline: enabled

class Cards::NotNowsController < ApplicationController
  include CardScoped

  def create
    @card.postpone
    render_card_replacement
  end
end
