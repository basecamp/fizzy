require "application_system_test_case"

class OauthConsentTest < ApplicationSystemTestCase
  # The consent form posts to us and we redirect to the client. Browsers hold
  # that redirect to the consent page's form-action, so this needs a real one.
  test "authorizing redirects the browser to a loopback client" do
    client = Oauth::Client.create! name: "Loopback Tool", dynamically_registered: true,
      redirect_uris: %w[ http://localhost/oauth-test-callback ]
    callback = "http://localhost:#{Capybara.current_session.server.port}/oauth-test-callback"

    sign_in_as users(:david)
    visit new_oauth_authorization_url(script_name: nil, client_id: client.client_id, redirect_uri: callback,
      response_type: "code", code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
      code_challenge_method: "S256", scope: "read", state: "xyz123")
    click_on "Authorize"

    assert_current_path %r{\A#{Regexp.escape(callback)}\?.*code=}, url: true
  end
end
