require "test_helper"

class TrustedTypesViolationTest < ActiveSupport::TestCase
  test "keeps the sink, script location and route, and drops what was written" do
    violation = TrustedTypesViolation.parse(report)

    assert_equal "Element innerHTML", violation.sink
    assert_equal "/assets/lexxy-0123abcd.js:8063:17", violation.source
    assert_equal "cards#show", violation.route
    assert_not_includes violation.to_s, "SYNTHETIC"
    assert_not_includes violation.to_s, "query"
  end

  test "names inline scripts and unknown pages" do
    violation = TrustedTypesViolation.parse(report("source-file" => "", "document-uri" => "https://app.fizzy.do/nowhere/at/all"))

    assert_equal "(inline):8063:17", violation.source
    assert_equal "unknown", violation.route
  end

  test "keeps what's injected or mistyped out of the log line" do
    violation = TrustedTypesViolation.parse(report(
      "script-sample" => "Element innerHTML\nforged=line|text",
      "source-file" => "https://app.fizzy.do/assets/app.js?token=private",
      "line-number" => {},
      "column-number" => [ 1 ]
    ))

    assert_equal "Element innerHTMLforgedline", violation.sink
    assert_equal "/assets/app.js:0:0", violation.source
  end

  test "drops a line or column no script could have" do
    violation = TrustedTypesViolation.parse(%({"csp-report":{"effective-directive":"require-trusted-types-for","source-file":"https://app.fizzy.do/assets/app.js","line-number":#{"9" * 15_000},"column-number":-1}}))

    assert_equal "/assets/app.js:0:0", violation.source
  end

  test "ignores reports for other directives" do
    assert_nil TrustedTypesViolation.parse(report("effective-directive" => "script-src-elem"))
  end

  test "ignores what isn't a CSP report" do
    assert_nil TrustedTypesViolation.parse("not json")
    assert_nil TrustedTypesViolation.parse("[]")
    assert_nil TrustedTypesViolation.parse(nil)
  end

  private
    def report(overrides = {})
      { "csp-report" => {
          "effective-directive" => "require-trusted-types-for",
          "script-sample" => "Element innerHTML|<p>SYNTHETIC private text</p>",
          "source-file" => "https://app.fizzy.do/assets/lexxy-0123abcd.js",
          "line-number" => 8063,
          "column-number" => 17,
          "document-uri" => "https://app.fizzy.do/897362094/cards/42?query=private"
        }.merge(overrides) }.to_json
    end
end
