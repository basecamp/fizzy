class Cards::LinksController < ApplicationController
  include CardScoped

  def new
    existing_ids = @card.linked_cards.pluck(:id) + @card.linking_cards.pluck(:id)
    @available_cards = Current.account.cards
                              .where.not(id: [@card.id] + existing_ids)
                              .order(number: :desc)
                              .limit(50)
    @link_type = params[:link_type] || "related"
    fresh_when etag: [@available_cards, @card.outgoing_links]
  end

  def create
    target = Current.account.cards.find(params[:target_card_id])
    link_type = params[:link_type]&.to_sym || :related

    @card.toggle_link(target, link_type: link_type)
    @target = target

    respond_to do |format|
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  def destroy
    @link = @card.outgoing_links.find(params[:id])
    @target = @link.target_card
    @link.destroy

    respond_to do |format|
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  def search
    query = params[:q].to_s.strip
    @link_type = params[:link_type] || "related"
    @cards = Current.account.cards
                    .where.not(id: @card.id)
                    .search_by_title_or_number(query)
                    .order(number: :desc)
                    .limit(20)

    render partial: "cards/links/search_results", locals: { cards: @cards, card: @card, link_type: @link_type }
  end
end
