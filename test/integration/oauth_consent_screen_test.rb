require "test_helper"

class OauthConsentScreenTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :david
  end

  test "a self-registered web app goes by its callback's host, named once, its own name quoted beneath" do
    client = Oauth::Client.create! name: "Totally Fizzy", dynamically_registered: true,
      redirect_uris: %w[ https://connector.example.com/callback ]

    get_consent_screen client

    assert_response :success
    assert_select "title", text: /Connect the app at connector\.example\.com to Fizzy/
    assert_select "h1", text: "Connect the app at connector.example.com to Fizzy?"
    assert_select ".oauth-client__self-name", text: /\ASays it’s “Totally Fizzy”\z/
    assert_select ".oauth-client__warning", text: /\AWe haven’t checked this app\. Only authorize it if you trust that address\.\z/
    assert_equal 1, response.parsed_body.at("body").text.scan("connector.example.com").size
  end

  test "a self-registered app on this device is named as one" do
    get_consent_screen oauth_clients(:mcp_client)

    assert_response :success
    assert_select "h1", text: "Connect an app on your device to Fizzy?"
    assert_select ".oauth-client__self-name", text: /\ASays it’s “Test MCP Client”\z/
    assert_select ".oauth-client__warning", text: /\AWe haven’t checked this app\. Only authorize it if you started it\.\z/
  end

  test "a trusted app is known by its name and carries no warning" do
    get_consent_screen oauth_clients(:trusted_client)

    assert_response :success
    assert_select "h1", text: "Connect Trusted First-Party App to Fizzy?"
    assert_select ".oauth-client__made-by", text: "Made by 37signals."
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
    assert_select ".oauth-access__choice", text: /Read only.*It can't change anything/m
    assert_select ".oauth-access__choice", text: /Read and write.*delete cards/m
    assert_select ".oauth-access__reach", text: /\AIt acts as you, so it reaches only what you can, in every account you belong to\.\z/
    assert_select ".oauth-consent__fine-print", text: /\AYou can disconnect it anytime in Connected apps\.\z/
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
