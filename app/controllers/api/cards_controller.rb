class Api::CardsController < Api::BaseController
  before_action :set_board, only: [:create]
  before_action :set_card, only: [:move, :close, :reopen, :assign, :tag]

  def create
    column = find_column_by_name(params[:column]) if params[:column].present?
    
    card = @board.cards.create!(
      creator: Current.user,
      title: params[:title] || "Untitled",
      description: params[:description],
      column: column,
      status: "published"
    )

    # Add tags if provided
    if params[:tags].present?
      Array(params[:tags]).each do |tag_title|
        card.toggle_tag_with(tag_title.to_s.strip.gsub(/\A#/, ""))
      end
    end

    render json: card_json(card), status: :created
  end

  def move
    raise ArgumentError, "to_column parameter is required" unless params[:to_column].present?
    
    column = find_column_by_name(params[:to_column])
    @card.triage_into(column)
    
    render json: card_json(@card.reload)
  end

  def close
    @card.close(user: Current.user)
    
    render json: card_json(@card.reload)
  end

  def reopen
    @card.reopen(user: Current.user)
    
    render json: card_json(@card.reload)
  end

  def assign
    user = Current.account.users.find(params[:user_id])
    @card.toggle_assignment(user)
    
    render json: card_json(@card.reload)
  end

  def tag
    tags = Array(params[:tags] || [])
    
    tags.each do |tag_title|
      @card.toggle_tag_with(tag_title.to_s.strip.gsub(/\A#/, ""))
    end
    
    render json: card_json(@card.reload)
  end

  private
    def set_board
      @board = Current.account.boards.find(params[:board_id])
    end

    def set_card
      @card = Current.account.cards.find_by!(number: params[:card_id])
    end

    def find_column_by_name(column_name)
      return nil unless column_name.present?
      
      @card&.board&.columns&.find_by(name: column_name) ||
      @board&.columns&.find_by(name: column_name) ||
      (raise ActiveRecord::RecordNotFound, "Column '#{column_name}' not found")
    end

    def card_json(card)
      {
        id: card.number,
        title: card.title,
        description: card.description&.to_plain_text,
        status: card.status,
        column: card.column&.name,
        board_id: card.board_id,
        tags: card.tags.pluck(:title),
        assignees: card.assignees.map { |u| { id: u.id, name: u.name } },
        created_at: card.created_at.iso8601,
        updated_at: card.updated_at.iso8601
      }
    end
end
