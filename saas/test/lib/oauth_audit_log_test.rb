require "test_helper"

class OauthAuditLogTest < ActionDispatch::IntegrationTest
  setup do
    @log = Fizzy::Saas::OauthAuditLog.new(ActiveSupport::Logger.new(@output = StringIO.new))
    Rails.event.subscribe(@log) { |event| event[:name].start_with?("oauth.") }
    @client = oauth_clients(:mcp_client)
  end

  teardown { Rails.event.unsubscribe(@log) }

  test "the engine writes OAuth events to the structured log" do
    assert Rails.event.subscribers.any? { |entry| entry[:subscriber].is_a?(Fizzy::Saas::OauthAuditLog) && !entry[:subscriber].equal?(@log) }
  end

  test "each event is a line of its own, joined to its request by transaction id" do
    grant = identities(:david).access_tokens.create!(oauth_client: @client, permission: :read)
    @output.truncate(0)
    @output.rewind

    untenanted { post oauth_token_path, params: { grant_type: "refresh_token", refresh_token: grant.raw_refresh_token, client_id: @client.client_id } }
    refreshed = response.parsed_body

    lines = @output.string.lines.map { |line| JSON.parse(line) }
    assert_equal [ "oauth.token.refreshed" ], lines.map { |line| line.dig("event", "action") }

    line = lines.sole
    assert_equal response.request.uuid, line.dig("transaction", "id")
    assert_equal "fizzy", line.dig("rails", "application")
    assert_equal({ "app" => "fizzy", "event" => "oauth.token.refreshed", "client_id" => @client.client_id, "client_class" => "dcr",
      "client_type" => "public", "grant_id" => grant.id, "family_id" => grant.id, "identity_id" => identities(:david).id,
      "tenant_id" => nil, "actor" => "client", "reason" => nil, "request_id" => response.request.uuid,
      "grant_type" => "refresh_token", "permission" => "read" }, line["oauth"])
    assert_nothing_raised { Time.iso8601(line["@timestamp"]) }

    [ grant.raw_token, grant.raw_refresh_token, refreshed["access_token"], refreshed["refresh_token"] ].each do |secret|
      assert_not_includes @output.string, secret
      assert_not_includes @output.string, TokenDigester.digest(secret)
    end
  end

  test "a line carries no IP address or user agent" do
    untenanted do
      post oauth_clients_path, as: :json, params: { redirect_uris: [ "http://127.0.0.1:9999/callback" ] },
        headers: { "User-Agent" => "AuditAgent/1.0", "REMOTE_ADDR" => "203.0.113.9" }
    end

    assert_response :created
    assert_match "oauth.client.registered", @output.string
    assert_no_match "AuditAgent", @output.string
    assert_no_match "203.0.113.9", @output.string
  end
end
