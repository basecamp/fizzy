require "test_helper"

class OauthConsentScreenTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :david
  end

  test "a self-registered web app goes by its callback's host, its own name quoted beside it" do
    client = Oauth::Client.create! name: "Totally Fizzy", dynamically_registered: true,
      redirect_uris: %w[ https://connector.example.com/callback ]

    get_consent_screen client

    assert_response :success
    assert_select "title", text: /Authorize connector.example.com/
    assert_select ".oauth-client__name", text: "connector.example.com"
    assert_select ".oauth-client__self-name", text: /“Totally Fizzy”\s+·\s+name set by the app at\s+connector.example.com/
    assert_select ".oauth-client__warning", text: /Fizzy hasn't checked this app/
    assert_select ".oauth-consent__destination strong", text: "connector.example.com"
  end

  test "a self-registered app on this device is named as one" do
    get_consent_screen oauth_clients(:mcp_client)

    assert_response :success
    assert_select ".oauth-client__name", text: "An app on your device"
    assert_select ".oauth-client__self-name", text: /“Test MCP Client”\s+·\s+name set by an app running on your device/
    assert_select ".oauth-client__warning", text: /only authorize it if you started it/
    assert_select ".oauth-consent__destination", text: /the app on your device/
  end

  test "a trusted app is known by its name and carries no warning" do
    get_consent_screen oauth_clients(:trusted_client)

    assert_response :success
    assert_select ".oauth-client__name", text: "Trusted First-Party App"
    assert_select ".oauth-client__made-by", text: "Made by 37signals"
    assert_select ".oauth-client__self-name", count: 0
    assert_select ".oauth-client__warning", count: 0
  end

  test "bidirectional controls are stripped from a self-registered name" do
    client = Oauth::Client.create! name: "Good‮ppa‬ App", dynamically_registered: true,
      redirect_uris: %w[ http://127.0.0.1:8888/callback ]

    get_consent_screen client

    assert_response :success
    assert_no_match "‮", response.body
    assert_select ".oauth-client__self-name bdi", text: "Goodppa App"
  end

  test "each access level says what it lets the app do" do
    get_consent_screen oauth_clients(:mcp_client), scope: "read write"

    assert_response :success
    assert_select ".oauth-access__choice", count: 2
    assert_select ".oauth-access__choice", text: /Read only.*can't change anything/m
    assert_select ".oauth-access__choice", text: /Read and write.*delete cards/m
    assert_select ".oauth-access__reach", text: /every account you belong to/
  end

  test "the person sees who they're signed in as" do
    get_consent_screen oauth_clients(:mcp_client)

    assert_select ".oauth-consent__identity strong", text: identities(:david).email_address
  end

  test "an error before consent is shown on Fizzy, with what to do next" do
    get_consent_screen oauth_clients(:mcp_client), redirect_uri: "https://evil.example.com/callback"

    assert_response :bad_request
    assert_select "h2", text: "Can't authorize this app"
    assert_select "p", text: /Nothing was shared/
    assert_select "code", text: "invalid_request"
  end

  private
    def get_consent_screen(client, **overrides)
      untenanted do
        get new_oauth_authorization_path, params: {
          client_id: client.client_id,
          redirect_uri: client.redirect_uris.first,
          response_type: "code",
          code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
          code_challenge_method: "S256",
          scope: "read",
          state: "xyz123"
        }.merge(overrides)
      end
    end
end
