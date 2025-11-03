class Cards::CollectionsController < ApplicationController
  include CollectionScoped

  skip_before_action :set_collection, only: %i[ edit ]

  def edit
    @card = Current.user.accessible_cards.find(params[:card_id])
    @collections = Current.user.collections.ordered_by_recently_accessed
  end

  def update
    @card = Current.user.accessible_cards.find(params[:card_id])
    @card.move_to(@collection)
    redirect_to @card
  end
end
