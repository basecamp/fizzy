require "test_helper"

class StaticCspTest < ActionDispatch::IntegrationTest
  STATIC_POLICY = "default-src 'none'; img-src 'self'; style-src 'self'; " \
    "base-uri 'none'; form-action 'none'; frame-ancestors 'none'"

  STATIC_PAGES = %w[ /400.html /404.html /406-unsupported-browser.html /422.html /500.html ]

  test "static pages are served with the locked-down static policy and no inline script" do
    STATIC_PAGES.each do |page|
      get page

      assert_response :ok
      assert_equal STATIC_POLICY, response.headers[ActionDispatch::Constants::CONTENT_SECURITY_POLICY],
        "#{page} must carry the static CSP"
      assert_no_match(/<script|\bon\w+\s*=|javascript:/i, response.body, "#{page} must stay script-free")
    end
  end

  test "error responses rendered through the exceptions app carry the static policy" do
    without_detailed_exceptions do
      get "/nonexistent/path"
    end

    assert_response :not_found
    assert_equal STATIC_POLICY, response.headers[ActionDispatch::Constants::CONTENT_SECURITY_POLICY]
  end

  test "dynamic responses keep the app policy, not the static one" do
    sign_in_as identities(:david)
    get root_url

    csp = response.headers[ActionDispatch::Constants::CONTENT_SECURITY_POLICY]
    assert_includes csp, "script-src"
    assert_not_equal STATIC_POLICY, csp
  end

  private
    # Suppress the diagnostics page the test environment would otherwise
    # render, so the request falls through to the exceptions app like in
    # production.
    def without_detailed_exceptions
      env_config = Rails.application.env_config
      original = env_config["action_dispatch.show_detailed_exceptions"]
      env_config["action_dispatch.show_detailed_exceptions"] = false
      yield
    ensure
      env_config["action_dispatch.show_detailed_exceptions"] = original
    end
end
