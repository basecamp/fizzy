module Mcp::Tools
  extend self

  TOOLS = [
    {
      name: "create_board",
      title: "Create Board",
      description: "Create a new board for organizing work",
      inputSchema: {
        type: "object",
        properties: {
          account: { type: "string", description: "Account ID (required)" },
          name: { type: "string", description: "Board name" },
          columns: { type: "array", items: { type: "string" }, description: "Column names (default: Backlog, In Progress, Done)" }
        },
        required: %w[ account name ]
      },
      annotations: {
        readOnlyHint: false,
        destructiveHint: false,
        idempotentHint: false,
        openWorldHint: false
      }
    },
    {
      name: "create_card",
      title: "Create Card",
      description: "Create a new card on a board",
      inputSchema: {
        type: "object",
        properties: {
          account: { type: "string", description: "Account ID (required)" },
          title: { type: "string", description: "What needs to be done" },
          board: { type: "string", description: "Board name or ID (optional, uses most recent)" },
          description: { type: "string", description: "Details, context, acceptance criteria" }
        },
        required: %w[ account title ]
      },
      annotations: {
        readOnlyHint: false,
        destructiveHint: false,
        idempotentHint: false,
        openWorldHint: false
      }
    },
    {
      name: "update_card",
      title: "Update Card",
      description: "Update a card or add a comment",
      inputSchema: {
        type: "object",
        properties: {
          account: { type: "string", description: "Account ID (required)" },
          card: { type: "string", description: "Card number (e.g. '123' or '#123')" },
          title: { type: "string", description: "New title" },
          description: { type: "string", description: "New description" },
          comment: { type: "string", description: "Add a comment to the card" }
        },
        required: %w[ account card ]
      },
      annotations: {
        readOnlyHint: false,
        destructiveHint: false,
        idempotentHint: false,
        openWorldHint: false
      }
    },
    {
      name: "move_card",
      title: "Move Card",
      description: "Move a card to a different column",
      inputSchema: {
        type: "object",
        properties: {
          account: { type: "string", description: "Account ID (required)" },
          card: { type: "string", description: "Card number" },
          to: { type: "string", description: "Column name, or: 'next', 'done', 'backlog'" }
        },
        required: %w[ account card to ]
      },
      annotations: {
        readOnlyHint: false,
        destructiveHint: false,
        idempotentHint: true,
        openWorldHint: false
      }
    }
  ]

  def list
    { tools: TOOLS }
  end

  def call(name, arguments, identity:)
    args = arguments.to_h.symbolize_keys

    # Validate and set account context
    account = resolve_account(args.delete(:account), identity)
    user = identity.users.find_by!(account: account)

    Current.account = account
    Current.user = user

    case name
    when "create_board" then create_board(**args)
    when "create_card"  then create_card(**args)
    when "update_card"  then update_card(**args)
    when "move_card"    then move_card(**args)
    else
      raise ArgumentError, "Unknown tool: #{name}"
    end
  end

  private
    def resolve_account(account_id, identity)
      raise ArgumentError, "account is required" if account_id.blank?

      identity.accounts.find_by!(id: account_id)
    rescue ActiveRecord::RecordNotFound
      raise ArgumentError, "Account not found or not accessible: #{account_id}"
    end

    def create_board(name:, columns: nil)
      columns ||= [ "Backlog", "In Progress", "Done" ]

      board = Current.user.account.boards.create!(name: name, creator: Current.user, all_access: true)
      columns.each { |col| board.columns.create!(name: col) }

      tool_result board_summary(board)
    end

    def create_card(title:, board: nil, description: nil)
      board = resolve_board(board)
      card = board.cards.create! \
        title: title,
        description: description,
        creator: Current.user,
        status: "published"

      tool_result card_summary(card)
    end

    def update_card(card:, title: nil, description: nil, comment: nil)
      card = find_card(card)

      card.update!(title: title) if title.present?
      card.update!(description: description) if description.present?
      card.comments.create!(body: comment, creator: Current.user) if comment.present?

      tool_result card_summary(card.reload)
    end

    def move_card(card:, to:)
      card = find_card(card)
      column = resolve_column(card.board, to, card.column)
      card.update!(column: column)

      tool_result card_summary(card)
    end

    # Helpers

    def resolve_board(identifier)
      return Current.user.boards.order(updated_at: :desc).first! if identifier.blank?

      Current.user.boards.find_by(id: identifier) ||
        Current.user.boards.find_by!(name: identifier)
    end

    def find_card(identifier)
      number = identifier.to_s.delete_prefix("#")
      Current.user.accessible_cards.find_by!(number: number)
    end

    def resolve_column(board, target, current_column)
      case target.to_s.downcase
      when "done", "complete"
        board.columns.sorted.last
      when "backlog"
        board.columns.sorted.first
      when "next"
        if current_column
          current_column.right_column || board.columns.sorted.last
        else
          board.columns.sorted.second || board.columns.sorted.first
        end
      else
        board.columns.find_by!(name: target)
      end
    end

    def tool_result(content)
      {
        content: [ { type: "text", text: content.to_json } ]
      }
    end

    def board_summary(board)
      {
        id: board.id,
        name: board.name,
        columns: board.columns.sorted.pluck(:name),
        url: url_for(board)
      }
    end

    def card_summary(card)
      {
        number: card.number,
        title: card.title,
        board: card.board.name,
        column: card.column&.name,
        url: url_for(card)
      }
    end

    def url_for(record)
      Rails.application.routes.url_helpers.polymorphic_url(record,
        script_name: Current.account.slug,
        **url_options)
    end

    def url_options
      Rails.application.config.action_mailer.default_url_options || { host: "localhost" }
    end
end
