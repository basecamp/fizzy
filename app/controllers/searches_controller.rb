class SearchesController < ApplicationController
  include Turbo::DriveHelper

  def show
    @query = params[:q].blank? ? nil : params[:q]

    if card = find_card(@query)
      @card = card
    else
      set_page_and_extract_portion_from Current.user.search(@query)
      @recent_search_queries = Current.user.search_queries.order(updated_at: :desc).limit(10)
    end
  end

  private
    def find_card(query)
      return if query.blank?

      if query.to_s.match?(/\A#\d+\z/)
        number = query.to_s.delete_prefix("#").to_i
        Current.user.accessible_cards.find_by(number: number)
      else
        Current.user.accessible_cards.find_by(id: query)
      end
    end
end
