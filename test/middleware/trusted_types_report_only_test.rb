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
    headers = call_with "text/html", { HEADER => "default-src 'self'" }

    assert_equal [ "default-src 'self'", DIRECTIVE ], headers[HEADER]
  end

  test "leaves non-document responses alone" do
    headers = call_with "application/json"

    assert_nil headers[HEADER]
  end

  test "reports to the given uri" do
    headers = call_with "text/html", middleware_options: { report_uri: "/trusted_types_reports" }

    assert_equal "#{DIRECTIVE}; report-uri /trusted_types_reports", headers[HEADER]
  end

  test "adds the policy only to the sampled share of documents" do
    Random.stubs(:rand).returns(0.05)

    assert_equal DIRECTIVE, call_with("text/html", middleware_options: { sample_rate: 0.1 })[HEADER]
    assert_nil call_with("text/html", middleware_options: { sample_rate: 0.05 })[HEADER]
  end

  private
    def call_with(content_type, extra_headers = {}, middleware_options: {})
      inner = ->(env) { [ 200, { "content-type" => content_type, **extra_headers }, [ "" ] ] }
      app = Rack::Lint.new(TrustedTypesReportOnly.new(inner, **middleware_options))

      _status, headers, body = app.call(Rack::MockRequest.env_for("/"))
      body.close
      headers
    end
end
