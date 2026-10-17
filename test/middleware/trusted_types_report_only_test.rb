require "test_helper"
require "rack/lint"

class TrustedTypesReportOnlyTest < ActiveSupport::TestCase
  HEADER = "content-security-policy-report-only"
  DIRECTIVE = "require-trusted-types-for 'script'"

  test "adds the directive as the only report-only policy when the app sets none" do
    headers = call_with "text/html; charset=utf-8"

    assert_equal DIRECTIVE, headers[HEADER]
  end

  test "stacks a second header field beside an existing report-only policy" do
    headers = call_with "text/html", HEADER => "default-src 'self'"

    assert_equal [ "default-src 'self'", DIRECTIVE ], headers[HEADER]
  end

  test "leaves non-document responses alone" do
    headers = call_with "application/json"

    assert_nil headers[HEADER]
  end

  private
    def call_with(content_type, extra_headers = {})
      inner = ->(env) { [ 200, { "content-type" => content_type, **extra_headers }, [ "" ] ] }
      app = Rack::Lint.new(TrustedTypesReportOnly.new(inner))

      _status, headers, body = app.call(Rack::MockRequest.env_for("/"))
      body.close
      headers
    end
end
