require "ostruct"

class CardsController < ApplicationController
  include FilterScoped

  before_action :set_collection, only: %i[ create ]
  before_action :set_card, only: %i[ show edit update destroy ]

  enable_collection_filtering only: :index

  PAGE_SIZE = 25

  def index
    set_page_and_extract_portion_from @filter.cards
  end

  def create
    card = @collection.cards.create!
    redirect_to card
  end

  def show
    fresh_when etag: @card.cache_invalidation_parts.for_perma
  end

  def edit
  end

  def update
    @card.update! card_params

    if @card.published?
      render_card_replacement
    else
      redirect_to @card
    end
  end

  def destroy
    @card.destroy!
    redirect_to cards_path(collection_ids: [ @card.collection ]), notice: ("Card deleted" unless @card.creating?)
  end

  private
    def set_collection
      @collection = Current.user.collections.find(params[:collection_id])
    end

    def set_card
      @card = Current.user.accessible_cards.find params[:id]
    end

    def card_params
      params.expect(card: [ :status, :title, :description, :image, tag_ids: [] ])
    end

    def render_card_replacement
      render turbo_stream: turbo_stream.replace([ @card, :card_container ], partial: "cards/container", locals: { card: @card.reload })
    end
end
