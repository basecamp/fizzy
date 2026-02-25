class SearchesController < ApplicationController
  include Turbo::DriveHelper

  def show
    @query = params[:q].blank? ? nil : params[:q]

    if card = Current.user.accessible_cards.find_by_id(@query)
      @card = card
    else
      set_page_and_extract_portion_from Current.user.search(@query)
      @recent_search_queries = Current.user.search_queries.order(updated_at: :desc).limit(10)
    end
  end
end
