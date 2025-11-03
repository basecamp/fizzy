class Cards::CollectionsController < ApplicationController
  include CollectionScoped

  skip_before_action :set_collection, only: %i[ edit ]
  before_action :set_card

  def edit
    @collections = Current.user.collections.ordered_by_recently_accessed
    fresh_when @collections
  end

  def update
    @card.move_to(@collection)
    redirect_to @card
  end

  private
    def set_card
      @card = Current.user.accessible_cards.find(params[:card_id])
    end
end
