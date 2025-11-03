class Cards::ColumnsController < ApplicationController
  def edit
    @card = Current.user.accessible_cards.find(params[:card_id])
    @columns = @card.collection.columns

    fresh_when etag: [ @card, @columns ]
  end
end
