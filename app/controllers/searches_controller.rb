class SearchesController < ApplicationController
  include Turbo::DriveHelper

  # geared_pagination's own ratios, so the JSON arm and this one page alike.
  SEARCH_PAGE_SIZES = [ 15, 30, 50, 100 ].freeze

  # The last page inside the store's result window. Clamping keeps a deeper page rendering
  # empty, as it always has; without it the same URL raises.
  MAX_SEARCH_PAGE = 102

  def show
    @query = params[:q].blank? ? nil : params[:q]

    if card = Current.user.accessible_cards.find_by(number: @query)
      respond_to do |format|
        format.html { @card = card }
        format.json { set_page_and_extract_portion_from Current.user.accessible_cards.where(id: card.id) }
      end
    else
      respond_to do |format|
        format.html do
          @page = Current.user.search(@query).page(windowed_page_param, per_page: SEARCH_PAGE_SIZES)
        end

        format.json do
          set_page_and_extract_portion_from \
            Current.user.accessible_cards.mentioning(@query, user: Current.user).distinct.latest.preloaded
        end
      end
    end
  end

  private
    def windowed_page_param
      current_page_param.to_i > MAX_SEARCH_PAGE ? MAX_SEARCH_PAGE : current_page_param
    end
end
