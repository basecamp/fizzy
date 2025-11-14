class Prompts::CardsController < ApplicationController
  MAX_RESULTS = 10

  def index
    @cards = if filter_param.present?
      prepending_exact_matches_by_id(search_cards)
    else
      published_cards.latest
    end

    if stale? etag: @cards
      render layout: false
    end
  end

  private
    def filter_param
      params[:filter]
    end

    def search_cards
      published_cards
        .mentioning(params[:filter], user: Current.user)
        .reverse_chronologically
        .limit(MAX_RESULTS)
    end

    def published_cards
      Current.user.accessible_cards.published
    end

    def prepending_exact_matches_by_id(cards)
      if card_by_id = Current.user.accessible_cards.find_by(number: params[:filter])
        [ card_by_id ] + cards
      else
        cards
      end
    end
end
