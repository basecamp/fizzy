require "test_helper"

class McpTest < ActionDispatch::IntegrationTest
  setup do
    @bearer_token = { "HTTP_AUTHORIZATION" => "Bearer #{identity_access_tokens(:davids_api_token).token}" }
    @read_only_token = { "HTTP_AUTHORIZATION" => "Bearer #{identity_access_tokens(:jasons_api_token).token}" }
    @account = accounts("37s")
  end


  # Discovery

  test "discovery returns server metadata" do
    untenanted do
      get "/.well-known/mcp.json"
    end

    assert_response :success
    body = response.parsed_body

    assert_equal "Fizzy", body["name"]
    assert_equal "2025-06-18", body["mcp_version"]
    assert body["capabilities"].key?("tools")
    assert body["capabilities"].key?("resources")
    assert body["oauth"]["server"].present?
  end


  # Initialize

  test "initialize returns protocol info" do
    jsonrpc_call "initialize"

    assert_response :success
    result = response.parsed_body["result"]

    assert_equal "2025-06-18", result["protocolVersion"]
    assert_equal "Fizzy", result["serverInfo"]["name"]
    assert_equal "Fizzy Kanban", result["serverInfo"]["title"]
    assert result["capabilities"].key?("tools")
    assert result["capabilities"].key?("resources")
  end


  # Protocol version header

  test "requests require MCP-Protocol-Version header" do
    jsonrpc_call "tools/list"

    assert_response :success
  end

  test "unsupported protocol version returns error" do
    untenanted do
      post "/mcp",
        params: jsonrpc_request("tools/list"),
        headers: @bearer_token.merge("MCP-Protocol-Version" => "1999-01-01"),
        as: :json
    end

    assert_response :bad_request
    error = response.parsed_body["error"]
    assert_match "Unsupported protocol version", error["message"]
  end

  test "notifications (requests without id) return 202 accepted" do
    untenanted do
      post "/mcp",
        params: { jsonrpc: "2.0", method: "notifications/initialized" },
        headers: @bearer_token.merge("MCP-Protocol-Version" => Mcp::PROTOCOL_VERSION),
        as: :json
    end

    assert_response :accepted
    assert_empty response.body
  end

  test "notifications execute side effects before returning 202" do
    board = boards(:writebook)

    assert_difference "board.cards.count", 1 do
      untenanted do
        post "/mcp",
          params: {
            jsonrpc: "2.0",
            method: "tools/call",
            params: { name: "create_card", arguments: { account: @account.id, board: board.id, title: "Created via notification" } }
          },
          headers: @bearer_token.merge("MCP-Protocol-Version" => Mcp::PROTOCOL_VERSION),
          as: :json
      end
    end

    assert_response :accepted
    assert_empty response.body
    assert_equal "Created via notification", board.cards.last.title
  end


  # Tools

  test "tools/list returns available tools with annotations" do
    jsonrpc_call "tools/list"

    assert_response :success
    tools = response.parsed_body["result"]["tools"]

    tool_names = tools.map { |t| t["name"] }
    assert_includes tool_names, "create_board"
    assert_includes tool_names, "create_card"
    assert_includes tool_names, "update_card"
    assert_includes tool_names, "move_card"

    # Check tool has title and annotations
    create_board = tools.find { |t| t["name"] == "create_board" }
    assert_equal "Create Board", create_board["title"]
    assert create_board["annotations"].key?("readOnlyHint")
    assert create_board["annotations"].key?("destructiveHint")
  end

  test "tools/call create_board creates a new board" do
    assert_difference "Board.count", 1 do
      jsonrpc_call "tools/call", name: "create_board", arguments: { account: @account.id, name: "Agent Workspace" }
    end

    assert_response :success
    content = JSON.parse(response.parsed_body.dig("result", "content", 0, "text"))

    assert_equal "Agent Workspace", content["name"]
    assert_includes content["columns"], "Backlog"
    assert_includes content["columns"], "In Progress"
    assert_includes content["columns"], "Done"
  end

  test "tools/call create_board with custom columns" do
    jsonrpc_call "tools/call", name: "create_board", arguments: {
      account: @account.id,
      name: "Custom Flow",
      columns: [ "Queue", "Active", "Complete" ]
    }

    assert_response :success
    content = JSON.parse(response.parsed_body.dig("result", "content", 0, "text"))

    assert_equal [ "Queue", "Active", "Complete" ], content["columns"]
  end

  test "tools/call create_card creates a new card" do
    board = boards(:writebook)

    assert_difference "Card.count", 1 do
      jsonrpc_call "tools/call", name: "create_card", arguments: {
        account: @account.id,
        title: "New feature request",
        board: board.name,
        description: "Detailed description here"
      }
    end

    assert_response :success
    content = JSON.parse(response.parsed_body.dig("result", "content", 0, "text"))

    assert_equal "New feature request", content["title"]
    assert_equal "Writebook", content["board"]
  end

  test "tools/call create_card uses most recent board when not specified" do
    assert_difference "Card.count", 1 do
      jsonrpc_call "tools/call", name: "create_card", arguments: {
        account: @account.id,
        title: "Quick card"
      }
    end

    assert_response :success
  end

  test "tools/call without account returns error" do
    jsonrpc_call "tools/call", name: "create_board", arguments: { name: "No Account" }

    assert_response :bad_request
    error = response.parsed_body["error"]
    assert_match "account is required", error["message"]
  end

  test "tools/call with invalid account returns error" do
    jsonrpc_call "tools/call", name: "create_board", arguments: {
      account: "00000000-0000-0000-0000-000000000000",
      name: "Invalid Account"
    }

    assert_response :bad_request
    error = response.parsed_body["error"]
    assert_match "Account not found", error["message"]
  end

  test "tools/call update_card updates title" do
    card = cards(:logo)

    jsonrpc_call "tools/call", name: "update_card", arguments: {
      account: @account.id,
      card: card.number.to_s,
      title: "Updated title"
    }

    assert_response :success
    assert_equal "Updated title", card.reload.title
  end

  test "tools/call update_card adds comment" do
    card = cards(:logo)

    assert_difference "Comment.count", 1 do
      jsonrpc_call "tools/call", name: "update_card", arguments: {
        account: @account.id,
        card: "##{card.number}",
        comment: "Progress update from agent"
      }
    end

    assert_response :success
    assert_equal "Progress update from agent", card.comments.last.body.to_plain_text
  end

  test "tools/call move_card moves to column by name" do
    card = cards(:logo)
    assert_equal "Triage", card.column.name

    jsonrpc_call "tools/call", name: "move_card", arguments: {
      account: @account.id,
      card: card.number.to_s,
      to: "In progress"
    }

    assert_response :success
    assert_equal "In progress", card.reload.column.name
  end

  test "tools/call move_card moves to done" do
    card = cards(:logo)

    jsonrpc_call "tools/call", name: "move_card", arguments: {
      account: @account.id,
      card: card.number.to_s,
      to: "done"
    }

    assert_response :success
    assert_equal "Review", card.reload.column.name  # Last column
  end

  test "tools/call move_card moves to backlog" do
    card = cards(:text)
    assert_equal "In progress", card.column.name

    jsonrpc_call "tools/call", name: "move_card", arguments: {
      account: @account.id,
      card: card.number.to_s,
      to: "backlog"
    }

    assert_response :success
    assert_equal "Triage", card.reload.column.name  # First column
  end

  test "tools/call move_card moves to next column" do
    card = cards(:logo)
    assert_equal "Triage", card.column.name

    jsonrpc_call "tools/call", name: "move_card", arguments: {
      account: @account.id,
      card: card.number.to_s,
      to: "next"
    }

    assert_response :success
    assert_equal "In progress", card.reload.column.name
  end

  test "tools/call with read-only token fails for write operations" do
    untenanted do
      post "/mcp",
        params: jsonrpc_request("tools/call", name: "create_board", arguments: { account: @account.id, name: "Should fail" }),
        headers: @read_only_token.merge("MCP-Protocol-Version" => Mcp::PROTOCOL_VERSION),
        as: :json
    end

    assert_response :forbidden
  end

  test "tools/list succeeds with read-only token" do
    untenanted do
      post "/mcp",
        params: jsonrpc_request("tools/list"),
        headers: @read_only_token.merge("MCP-Protocol-Version" => Mcp::PROTOCOL_VERSION),
        as: :json
    end

    assert_response :success
    assert response.parsed_body["result"]["tools"].is_a?(Array)
  end

  test "resources/list succeeds with read-only token" do
    untenanted do
      post "/mcp",
        params: jsonrpc_request("resources/list"),
        headers: @read_only_token.merge("MCP-Protocol-Version" => Mcp::PROTOCOL_VERSION),
        as: :json
    end

    assert_response :success
    assert response.parsed_body["result"]["resources"].is_a?(Array)
  end

  test "resources/read succeeds with read-only token" do
    untenanted do
      post "/mcp",
        params: jsonrpc_request("resources/read", uri: "fizzy://accounts"),
        headers: @read_only_token.merge("MCP-Protocol-Version" => Mcp::PROTOCOL_VERSION),
        as: :json
    end

    assert_response :success
    assert response.parsed_body["result"]["contents"].is_a?(Array)
  end


  # Resources

  test "resources/list returns available resources" do
    jsonrpc_call "resources/list"

    assert_response :success
    resources = response.parsed_body["result"]["resources"]

    uris = resources.map { |r| r["uri"] || r["uriTemplate"] }
    assert_includes uris, "fizzy://accounts"
    assert_includes uris, "fizzy://accounts/{account_id}/overview"
    assert_includes uris, "fizzy://accounts/{account_id}/boards/{id}"
    assert_includes uris, "fizzy://accounts/{account_id}/cards/{number}"

    # Check resources have title
    accounts_resource = resources.find { |r| r["uri"] == "fizzy://accounts" }
    assert_equal "Available Accounts", accounts_resource["title"]
  end

  test "resources/read accounts returns list of accessible accounts" do
    jsonrpc_call "resources/read", uri: "fizzy://accounts"

    assert_response :success
    content = JSON.parse(response.parsed_body.dig("result", "contents", 0, "text"))

    assert content["accounts"].is_a?(Array)
    account_names = content["accounts"].map { |a| a["name"] }
    assert_includes account_names, "37signals"
  end

  test "resources/read overview returns boards and activity" do
    jsonrpc_call "resources/read", uri: "fizzy://accounts/#{@account.id}/overview"

    assert_response :success
    content = JSON.parse(response.parsed_body.dig("result", "contents", 0, "text"))

    assert_equal @account.id, content["account"]["id"]
    assert content["boards"].is_a?(Array)
    assert content["in_progress"].is_a?(Array)
    assert content["recent_activity"].is_a?(Array)
  end

  test "resources/read board returns board details" do
    board = boards(:writebook)

    jsonrpc_call "resources/read", uri: "fizzy://accounts/#{@account.id}/boards/#{board.id}"

    assert_response :success
    content = JSON.parse(response.parsed_body.dig("result", "contents", 0, "text"))

    assert_equal board.id, content["id"]
    assert_equal "Writebook", content["name"]
    assert content["columns"].is_a?(Array)
  end

  test "resources/read card returns card details" do
    card = cards(:logo)

    jsonrpc_call "resources/read", uri: "fizzy://accounts/#{@account.id}/cards/#{card.number}"

    assert_response :success
    content = JSON.parse(response.parsed_body.dig("result", "contents", 0, "text"))

    assert_equal card.number, content["number"]
    assert_equal card.title, content["title"]
  end

  test "resources/read with invalid account returns error" do
    jsonrpc_call "resources/read", uri: "fizzy://accounts/00000000-0000-0000-0000-000000000000/overview"

    assert_response :bad_request
    error = response.parsed_body["error"]
    assert_match "Account not found", error["message"]
  end


  # Error handling

  test "unknown method returns method_not_found error" do
    jsonrpc_call "unknown/method"

    assert_response :not_found
    error = response.parsed_body["error"]

    assert_equal(-32601, error["code"])
  end

  test "unknown tool returns error" do
    jsonrpc_call "tools/call", name: "unknown_tool", arguments: { account: @account.id }

    assert_response :bad_request
    error = response.parsed_body["error"]

    assert_equal(-32602, error["code"])
    assert_match "Unknown tool", error["message"]
  end

  test "card not found returns error" do
    jsonrpc_call "tools/call", name: "move_card", arguments: { account: @account.id, card: "99999", to: "done" }

    assert_response :bad_request
    error = response.parsed_body["error"]

    assert_match "not found", error["message"]
  end


  private
    def jsonrpc_call(method, **params)
      untenanted do
        post "/mcp",
          params: jsonrpc_request(method, **params),
          headers: @bearer_token.merge("MCP-Protocol-Version" => Mcp::PROTOCOL_VERSION),
          as: :json
      end
    end

    def jsonrpc_request(method, **params)
      {
        jsonrpc: "2.0",
        id: SecureRandom.uuid,
        method: method,
        params: params.presence
      }.compact
    end
end
