class Api::CardsController < Api::BaseController
  before_action :set_board, only: [:create]
  before_action :set_card, only: [:move, :close, :reopen, :assign, :tag, :update]

  def index
    cards = Current.user.accessible_cards.published
    
    # Filter by board
    if params[:board_id].present?
      board = Current.account.boards.find(params[:board_id])
      cards = cards.where(board: board)
    end
    
    # Filter by assignees
    if params[:assignee_ids].present?
      assignee_ids = Array(params[:assignee_ids])
      assignees = Current.account.users.where(id: assignee_ids)
      if assignees.any?
        cards = cards.assigned_to(assignees)
      else
        # If assignee_ids are specified but none found, return empty result
        cards = cards.none
      end
    end
    
    # Filter by creators
    if params[:creator_ids].present?
      creator_ids = Array(params[:creator_ids])
      # If creator_ids are specified, filter by them (empty array will return no results)
      cards = cards.where(creator_id: creator_ids)
    end
    
    # Filter by column
    if params[:column].present?
      column_name = params[:column].strip
      normalized = column_name.upcase
      
      case normalized
      when "NOT NOW"
        cards = cards.postponed
      when "MAYBE?"
        cards = cards.awaiting_triage
      when "DONE"
        cards = cards.closed
      else
        # Find column by name (case-insensitive)
        # Search across all accessible boards
        accessible_board_ids = Current.user.boards.pluck(:id)
        column = Column.joins(:board)
          .where(boards: { id: accessible_board_ids, account_id: Current.account.id })
          .find { |c| c.name.casecmp?(column_name) }
        
        if column
          cards = cards.where(column: column)
        else
          raise ActiveRecord::RecordNotFound, "Column '#{column_name}' not found"
        end
      end
    end
    
    # Filter by tags
    if params[:tags].present?
      tag_titles = Array(params[:tags]).map { |t| t.to_s.strip.gsub(/\A#/, "").downcase }
      tags = Current.account.tags.where(title: tag_titles)
      if tags.any?
        cards = cards.tagged_with(tags)
      else
        # If tags are specified but none found, return empty result
        cards = cards.none
      end
    end
    
    # Filter by creation date
    if params[:created_at].present?
      created_at_param = params[:created_at]
      
      # Try parsing as time window first
      time_window = TimeWindowParser.parse(created_at_param)
      
      if time_window
        cards = cards.where(created_at: time_window)
      else
        # Try parsing as ISO8601 date or datetime
        begin
          if created_at_param.match?(/^\d{4}-\d{2}-\d{2}$/)
            # Date only - create range for the day
            date = Date.parse(created_at_param)
            cards = cards.where(created_at: date.beginning_of_day..date.end_of_day)
          else
            # Full datetime
            datetime = Time.parse(created_at_param)
            cards = cards.where(created_at: datetime)
          end
        rescue ArgumentError, Date::Error
          # Invalid date format, ignore filter
        end
      end
    end
    
    # Filter by status
    status = params[:status] || "all"
    case status
    when "closed"
      cards = cards.closed
    when "not_now"
      cards = cards.postponed
    when "all"
      # Include all statuses (open, closed, postponed)
    end
    
    # Sort
    sort = params[:sort] || "latest"
    case sort
    when "newest"
      cards = cards.reverse_chronologically
    when "oldest"
      cards = cards.chronologically
    when "latest"
      cards = cards.latest
    end
    
    render json: cards.map { |card| card_json(card) }
  end

  def create
    column_name = params[:column]&.strip
    column = find_column_by_name(column_name) if column_name.present?
    
    card = @board.cards.create!(
      creator: Current.user,
      title: params[:title] || "Untitled",
      description: params[:description],
      column: column,
      status: "published"
    )

    # Handle virtual columns
    case column_name&.upcase
    when "NOT NOW"
      card.postpone(user: Current.user)
    when "DONE"
      card.close(user: Current.user)
    when "MAYBE?"
      card.send_back_to_triage(skip_event: false)
    end

    # Add tags if provided
    if params[:tags].present?
      Array(params[:tags]).each do |tag_title|
        card.toggle_tag_with(tag_title.to_s.strip.gsub(/\A#/, ""))
      end
    end

    render json: card_json(card.reload), status: :created
  end

  def move
    raise ArgumentError, "to_column parameter is required" unless params[:to_column].present?
    
    column_name = params[:to_column].strip
    column = find_column_by_name(column_name)
    
    # Handle virtual columns
    case column_name.upcase
    when "NOT NOW"
      @card.postpone(user: Current.user)
    when "DONE"
      @card.close(user: Current.user)
    when "MAYBE?"
      @card.send_back_to_triage(skip_event: false)
    else
      @card.triage_into(column)
    end
    
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

  def update
    @card.update!(card_update_params)
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
      
      # Virtual columns are handled separately, return nil to indicate they're virtual
      normalized = column_name.upcase.strip
      return nil if normalized == "NOT NOW" || normalized == "MAYBE?" || normalized == "DONE"
      
      # Case-insensitive search for regular columns, but preserve original case in response
      columns = @card&.board&.columns || @board&.columns
      column = columns&.find { |c| c.name.casecmp?(column_name.strip) }
      
      column || (raise ActiveRecord::RecordNotFound, "Column '#{column_name}' not found")
    end

    def card_update_params
      params.permit(:title, :description)
    end

    def card_json(card)
      column_name = if card.closed?
        "DONE"
      elsif card.postponed?
        "NOT NOW"
      elsif card.awaiting_triage?
        "MAYBE?"
      else
        card.column&.name
      end

      {
        id: card.number,
        title: card.title,
        description: card.description&.to_plain_text,
        status: card.status,
        column: column_name,
        board_id: card.board_id,
        tags: card.tags.pluck(:title),
        assignees: card.assignees.map { |u| { id: u.id, name: u.name } },
        creator: {
          id: card.creator.id,
          name: card.creator.name
        },
        created_at: card.created_at.iso8601,
        updated_at: card.updated_at.iso8601
      }
    end

    def search
      raise ArgumentError, "q parameter is required" unless params[:q].present?
      
      query = params[:q].strip
      limit = [ (params[:limit] || 10).to_i, 50 ].min
      
      cards = Current.user.accessible_cards.published
      
      # Filter by board if provided
      if params[:board_id].present?
        board = Current.account.boards.find(params[:board_id])
        cards = cards.where(board: board)
      end
      
      # Search by number, title, or description
      if query =~ /^\d+$/
        # Number search
        cards = cards.where(number: query.to_i)
      else
        # Text search in title and description
        cards = cards.where(
          "cards.title LIKE ? OR EXISTS (SELECT 1 FROM action_text_rich_texts WHERE action_text_rich_texts.record_type = 'Card' AND action_text_rich_texts.record_id = cards.id AND action_text_rich_texts.name = 'description' AND action_text_rich_texts.body LIKE ?)",
          "%#{query}%", "%#{query}%"
        )
      end
      
      cards = cards.limit(limit).preloaded
      
      render json: {
        cards: cards.map { |card|
          column_name = if card.closed?
            "DONE"
          elsif card.postponed?
            "NOT NOW"
          elsif card.awaiting_triage?
            "MAYBE?"
          else
            card.column&.name
          end
          
          {
            id: card.number,
            title: card.title,
            board_id: card.board_id,
            column: column_name
          }
        }
      }
    end
end
