class SearchesController < ApplicationController
  include Search::QueryTermsScoped, Turbo::DriveHelper

  def show
    if card = Current.user.accessible_cards.find_by_id(@query_terms)
      @card = card
    else
      perform_search
    end
  end

  private
    def perform_search
      set_page_and_extract_portion_from Current.user.search(@query_terms)
      @recent_search_queries = Current.user.search_queries.order(updated_at: :desc).limit(10)
    end
end
