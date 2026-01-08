module Mcp::Resources
  extend self

  RESOURCES = [
    {
      uri: "fizzy://accounts",
      name: "accounts",
      title: "Available Accounts",
      description: "List of accounts accessible to the authenticated identity",
      mimeType: "application/json"
    },
    {
      uriTemplate: "fizzy://accounts/{account_id}/overview",
      name: "overview",
      title: "Workspace Overview",
      description: "Summary of boards and recent activity for an account",
      mimeType: "application/json"
    },
    {
      uriTemplate: "fizzy://accounts/{account_id}/boards/{id}",
      name: "board",
      title: "Board Details",
      description: "Board with columns and cards summary",
      mimeType: "application/json"
    },
    {
      uriTemplate: "fizzy://accounts/{account_id}/cards/{number}",
      name: "card",
      title: "Card Details",
      description: "Full card with comments and steps",
      mimeType: "application/json"
    }
  ]

  def list
    { resources: RESOURCES }
  end

  def read(uri, identity:)
    case uri
    when "fizzy://accounts"
      accounts(identity)
    when %r{\Afizzy://accounts/([^/]+)/overview\z}
      with_account($1, identity) { overview }
    when %r{\Afizzy://accounts/([^/]+)/boards/(.+)\z}
      with_account($1, identity) { board($2) }
    when %r{\Afizzy://accounts/([^/]+)/cards/(\d+)\z}
      with_account($1, identity) { card($2) }
    else
      raise ArgumentError, "Unknown resource: #{uri}"
    end
  end

  private
    def with_account(account_id, identity)
      account = identity.accounts.find_by!(id: account_id)
      user = identity.users.find_by!(account: account)

      Current.account = account
      Current.user = user

      yield
    rescue ActiveRecord::RecordNotFound
      raise ArgumentError, "Account not found or not accessible: #{account_id}"
    end

    def accounts(identity)
      {
        contents: [ {
          uri: "fizzy://accounts",
          mimeType: "application/json",
          text: {
            accounts: identity.accounts.map { |a|
              { id: a.id, name: a.name }
            }
          }.to_json
        } ]
      }
    end

    def overview
      {
        contents: [ {
          uri: "fizzy://accounts/#{Current.account.id}/overview",
          mimeType: "application/json",
          text: overview_content.to_json
        } ]
      }
    end

    def overview_content
      {
        account: { id: Current.account.id, name: Current.account.name },
        boards: Current.user.boards.includes(:columns).map { |b|
          {
            id: b.id,
            name: b.name,
            columns: b.columns.sorted.map(&:name),
            card_count: b.cards.count
          }
        },
        in_progress: in_progress_cards,
        recent_activity: recent_activity
      }
    end

    def in_progress_cards
      Current.user.accessible_cards
        .joins(:column)
        .where(columns: { name: [ "In Progress", "In progress", "Doing", "Active" ] })
        .limit(10)
        .map { |c| card_summary(c) }
    end

    def recent_activity
      Current.user.accessible_cards
        .order(updated_at: :desc)
        .limit(5)
        .map { |c| card_summary(c) }
    end

    def board(id)
      board = Current.user.boards.includes(:columns).find(id)

      {
        contents: [ {
          uri: "fizzy://accounts/#{Current.account.id}/boards/#{id}",
          mimeType: "application/json",
          text: board_content(board).to_json
        } ]
      }
    end

    def board_content(board)
      {
        id: board.id,
        name: board.name,
        columns: board.columns.sorted.map { |col|
          {
            id: col.id,
            name: col.name,
            card_count: col.cards.count,
            cards: col.cards.limit(5).map { |c| card_summary(c) }
          }
        }
      }
    end

    def card(number)
      card = Current.user.accessible_cards.find_by!(number: number)

      {
        contents: [ {
          uri: "fizzy://accounts/#{Current.account.id}/cards/#{number}",
          mimeType: "application/json",
          text: card_content(card).to_json
        } ]
      }
    end

    def card_content(card)
      {
        number: card.number,
        title: card.title,
        description: card.description&.to_plain_text,
        board: card.board.name,
        column: card.column&.name,
        created_at: card.created_at.iso8601,
        updated_at: card.updated_at.iso8601,
        assignees: card.assignees.map(&:name),
        steps: card.steps.map { |s| { text: s.description, done: s.checked? } },
        comments: card.comments.limit(20).map { |c|
          { author: c.creator.name, text: c.body.to_plain_text, at: c.created_at.iso8601 }
        }
      }
    end

    def card_summary(card)
      {
        number: card.number,
        title: card.title,
        board: card.board.name,
        column: card.column&.name
      }
    end
end
