# rbs_inline: enabled

class CardsController < ApplicationController
  include FilterScoped

  before_action :set_board, only: %i[ create ]
  before_action :set_card, only: %i[ show edit update destroy ]
  before_action :ensure_permission_to_administer_card, only: %i[ destroy ]

  # @rbs!
  #   @board: Board
  #   @card: Card

  def index
    set_page_and_extract_portion_from @filter.cards
  end

  def create
    card = @board.cards.find_or_create_by!(creator: Current.user, status: "drafted")
    redirect_to card
  end

  def show
  end

  def edit
  end

  def update
    @card.update! card_params
  end

  def destroy
    @card.destroy!
    redirect_to @card.board, notice: "Card deleted"
  end

  private
    def set_board
      @board = Current.user.boards.find params[:board_id]
    end

    def set_card
      @card = Current.user.accessible_cards.find_by!(number: params[:id])
    end

    def ensure_permission_to_administer_card
      head :forbidden unless Current.user.can_administer_card?(@card)
    end

    def card_params
      params.expect(card: [ :status, :title, :description, :image, tag_ids: [] ])
    end
end
