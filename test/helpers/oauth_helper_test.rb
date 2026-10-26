require "test_helper"

class OauthHelperTest < ActionView::TestCase
  test "a self-registered app is identified by its callback's host, port included when it isn't the default" do
    client = Oauth::Client.new name: "Hosted", dynamically_registered: true

    assert_equal "connector.example.com", oauth_client_display_identity(client, "https://connector.example.com/callback")
    assert_equal "connector.example.com:8443", oauth_client_display_identity(client, "https://connector.example.com:8443/callback")
    assert_equal "an app on your device", oauth_client_display_identity(client, "http://127.0.0.1:8888/callback")
    assert_equal "an app on your device", oauth_client_display_identity(client, "com.example.app:/callback")
  end

  test "a registered app is identified by its name" do
    assert_equal "Trusted First-Party App", oauth_client_display_identity(oauth_clients(:trusted_client), "https://app.example.com/oauth/callback")
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

  test "read's description names the people in every account, or in the one account a bound grant reaches" do
    client = oauth_clients(:mcp_client)

    assert_match "the people in your accounts.", oauth_access_levels(client).to_h.fetch("read")[:description]
    assert_match "the people in your account.", oauth_access_levels(client, one_account: true).to_h.fetch("read")[:description]
  end

  test "a redirect's host reads in lowercase, as a browser reads it" do
    assert_equal "connector.example.com:8443", oauth_redirect_host("https://Connector.EXAMPLE.com:8443/cb")
  end
end
