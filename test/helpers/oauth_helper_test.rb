require "test_helper"

class OauthHelperTest < ActionView::TestCase
  test "an authorization error reads in plain words: the caller's own, its code's, or a general one" do
    assert_equal "Choose an account.", oauth_error_message("invalid_request", "Choose an account.")
    assert_equal OAUTH_ERROR_MESSAGES["invalid_scope"], oauth_error_message("invalid_scope")
    assert_equal OAUTH_ERROR_MESSAGES["invalid_scope"], oauth_error_message(:invalid_scope, "")
    assert_equal "Something went wrong connecting this app.", oauth_error_message("server_error")
  end

  test "no plain-words message is a developer's string" do
    OAUTH_ERROR_MESSAGES.each_value do |message|
      assert_no_match(/_|redirect_uri|code_challenge|\bscope\b|S256/, message)
    end
  end

  test "a self name of nothing but direction controls reads as an unnamed app" do
    assert_equal "Unnamed app", oauth_client_self_name(Oauth::Client.new(name: "\u202E\u2066\u2069"))
  end

  test "a callback's host reads as a browser reads it, port included when it isn't the default, and nil on this device" do
    assert_equal "connector.example.com", oauth_redirect_host("https://Connector.Example.com/callback")
    assert_equal "connector.example.com:8443", oauth_redirect_host("https://connector.example.com:8443/callback")
    assert_nil oauth_redirect_host("http://127.0.0.1:8888/callback")
    assert_nil oauth_redirect_host("com.example.app:/callback")
  end

  test "a read-only client is offered read alone" do
    reader = Oauth::Client.new scopes: %w[ read ]

    assert_equal %w[ read ], oauth_access_levels(reader).map(&:first)
    assert_equal [ "read", "read write" ], oauth_access_levels(oauth_clients(:mcp_client)).map(&:first)
  end

  test "connected apps are grouped by kind, in a fixed order, skipping empty groups" do
    web = oauth_clients(:confidential_client)
    local = oauth_clients(:mcp_client)

    groups = connected_app_groups([ [ local, [] ], [ web, [] ] ])

    assert_equal %i[ web local ], groups.map(&:first)
    assert_equal [ [ web, [] ] ], groups.first.last
  end

  test "the account picker offers each account, preselecting the chosen one" do
    accounts = Account.order(:name).first(2)

    form_with(url: "/oauth/authorization") do |form|
      render partial: "oauth/authorizations/account_picker", locals: { form: form, accounts: accounts, selected_account_id: accounts.second.id }
    end

    assert_select "input[type=radio][name=account_id]", count: accounts.size
    assert_select "input[type=radio][name=account_id][checked][value=?]", accounts.second.id.to_s
  end

  test "the account picker names a lone account and carries it hidden" do
    account = Account.first

    form_with(url: "/oauth/authorization") do |form|
      render partial: "oauth/authorizations/account_picker", locals: { form: form, accounts: [ account ], selected_account_id: nil }
    end

    assert_select "input[type=radio]", count: 0
    assert_select "input[type=hidden][name=account_id][value=?]", account.id.to_s
    assert_select "bdi", text: account.name
  end

  test "a client's remote hosts skip its on-device callbacks and repeats" do
    client = Oauth::Client.new redirect_uris: %w[ http://127.0.0.1/cb https://a.example.com/x https://a.example.com/y com.example.app:/cb https://b.example.com:8443/cb ]

    assert_equal %w[ a.example.com b.example.com:8443 ], oauth_client_remote_hosts(client)
  end

  test "a client's destinations name its remote hosts, this device, or both" do
    assert_equal "the app at a.example.com or b.example.com:8443",
      oauth_client_destinations(Oauth::Client.new(redirect_uris: %w[ https://a.example.com/cb https://b.example.com:8443/cb ]))
    assert_equal "an app on your device",
      oauth_client_destinations(Oauth::Client.new(redirect_uris: %w[ http://127.0.0.1/cb com.example.app:/cb ]))
    assert_equal "the app at a.example.com, or an app on your device",
      oauth_client_destinations(Oauth::Client.new(redirect_uris: %w[ https://a.example.com/cb http://127.0.0.1/cb ]))
  end

  test "each access level has a short label and a line saying what it allows" do
    oauth_access_levels(oauth_clients(:mcp_client)).each do |_, level|
      assert level[:label].present?
      assert level[:description].present?
      assert_operator level[:description].split.size, :<=, 12
    end
  end
end
