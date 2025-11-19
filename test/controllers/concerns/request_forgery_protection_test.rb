require "test_helper"

class RequestForgeryProtectionTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin

    # Forgery protection is disabled in test environment so we need to
    # enable it here
    @original_allow_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @original_allow_forgery_protection
  end

  test "don't report when Sec-Fetch-Site is same-origin and CSRF token matches" do
    assert_log(excludes: "CSRF protection check") do
      post boards_path,
        params: { board: { name: "Test Board" }, authenticity_token: csrf_token },
        headers: { "Sec-Fetch-Site" => "same-origin" }
    end
  end

  test "don't report when Sec-Fetch-Site is same-site and CSRF token matches" do
    assert_log(excludes: "CSRF protection check") do
      post boards_path,
        params: { board: { name: "Test Board" }, authenticity_token: csrf_token },
        headers: { "Sec-Fetch-Site" => "same-site" }
    end
  end

  test "fail and report when token doesn't match, regardless of Sec-Fetch-Site" do
    assert_report

    assert_log(includes: [ "CSRF protection check", "sec_fetch_site pass (same-origin)", "token fail" ]) do
      assert_no_difference -> { Board.count } do
        post boards_path,
          params: { board: { name: "Test Board" }, authenticity_token: "invalid-token" },
          headers: { "Sec-Fetch-Site" => "same-origin" }
      end
    end
  end

  test "fail and report when Origin doesn't match, regardless of Sec-Fetch-Site" do
    assert_report

    assert_log(includes: [ "CSRF protection check", "sec_fetch_site pass (same-origin)",
      "token pass", "origin fail (evil-site.com)" ]) do
      assert_no_difference -> { Board.count } do
        post boards_path,
          params: { board: { name: "Test Board" }, authenticity_token: csrf_token },
          headers: { "Sec-Fetch-Site" => "same-origin", Origin: "evil-site.com" }
      end
    end
  end

  test "succeed and report when Sec-Fetch-Site is cross-site and CSRF token matches" do
    assert_report

    assert_log(includes: [ "CSRF protection check", "sec_fetch_site fail (cross-site)", "token pass" ]) do
      assert_difference -> { Board.count }, +1 do
        post boards_path,
          params: { board: { name: "Test Board" }, authenticity_token: csrf_token },
          headers: { "Sec-Fetch-Site" => "cross-site" }
      end
    end
  end

  test "succeed and report when Sec-Fetch-Site is none" do
    assert_report

    assert_log(includes: [ "CSRF protection check", "sec_fetch_site fail (none)", "token pass" ]) do
      assert_difference -> { Board.count }, +1 do
        post boards_path,
          params: { board: { name: "Test Board" }, authenticity_token: csrf_token },
          headers: { "Sec-Fetch-Site" => "none" }
      end
    end
  end

  test "succeed and report when Sec-Fetch-Site is missing" do
    assert_report

    assert_log(includes: [ "CSRF protection check", "sec_fetch_site fail ()", "token pass" ]) do
      assert_difference -> { Board.count }, +1 do
        post boards_path, params: { board: { name: "Test Board" }, authenticity_token: csrf_token }
      end
    end
  end

  test "don't report and succeed for GET requests" do
    assert_log(excludes: "CSRF protection check") do
      get board_url(boards(:writebook)), headers: { "Sec-Fetch-Site" => "cross-site" }
      assert_response :success
    end
  end

  test "GET requests succeed regardless of Sec-Fetch-Site header" do
    get board_url(boards(:writebook)), headers: { "Sec-Fetch-Site" => "cross-site" }

    assert_response :success
  end

  test "appends Sec-Fetch-Site to existing Vary header" do
    get board_url(boards(:writebook)), headers: { "Accept" => "text/html" }

    assert_response :success
    vary_values = response.headers["Vary"].split(",").map(&:strip)
    assert_includes vary_values, "Sec-Fetch-Site"
  end

  test "appends Sec-Fetch-Site to Vary header on POST requests" do
    post boards_path,
      params: { board: { name: "Test Board" }, authenticity_token: csrf_token },
      headers: { "Sec-Fetch-Site" => "same-origin" }

    assert_response :redirect
    assert_includes response.headers["Vary"], "Sec-Fetch-Site"
  end

  private
    def assert_log(includes: [], excludes: [], &block)
      original_logger = Rails.logger
      log_output = StringIO.new
      Rails.logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(log_output))

      yield

      Array(includes).each { assert_includes(log_output.string, it) }
      Array(excludes).each { assert_not_includes(log_output.string, it) }
    ensure
      Rails.logger = original_logger
    end

    def assert_report
      Sentry.expects(:capture_message).with do |message, **kwargs|
        message == "CSRF protection mismatch" && kwargs[:level] == :info
      end
    end

    def csrf_token
      @csrf_token ||= begin
        get new_board_url
        response.body[/name="authenticity_token" value="([^"]+)"/, 1]
      end
    end
end
