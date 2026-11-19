require "application_system_test_case"

class OauthConsentTest < ApplicationSystemTestCase
  # The test environment turns forgery protection off, and with it the Origin
  # check a browser's consent POST must pass in production. On here, so the
  # browser's own headers are judged: a consent page sent with
  # Referrer-Policy: no-referrer made the browser post Origin: null, which
  # Rails refuses (422) before anything else is weighed.
  setup do
    @original_allow_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @original_allow_forgery_protection
  end

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

  # Signing in submits through Turbo, which follows the redirect back to the
  # consent screen and swaps in its body without its headers. The document
  # would keep the sign-in page's form-action 'self' and block the redirect to
  # the client, so the consent screen must arrive as a full page load.
  test "authorizing after signing in mid-flow redirects the browser to the client" do
    client = Oauth::Client.create! name: "Loopback Tool", dynamically_registered: true,
      redirect_uris: %w[ http://localhost/oauth-test-callback ]
    callback = "http://localhost:#{Capybara.current_session.server.port}/oauth-test-callback"
    identity = users(:david).identity

    visit new_oauth_authorization_url(script_name: nil, client_id: client.client_id, redirect_uri: callback,
      response_type: "code", code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
      code_challenge_method: "S256", scope: "read", state: "xyz123")

    fill_in "email_address", with: identity.email_address
    click_on "Let’s go"
    assert_selector "h1", text: "Check your email"
    fill_in "code", with: identity.magic_links.active.last.code
    send_keys :enter

    assert_selector "h1", text: "Connect this app to Fizzy?"
    click_on "Authorize"

    assert_current_path %r{\A#{Regexp.escape(callback)}\?.*code=}, url: true
  end
end
