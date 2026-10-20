require "test_helper"

class TrustedTypesReportsControllerTest < ActionDispatch::IntegrationTest
  test "logs the violation without the content written to the sink" do
    Rails.logger.stubs(:info)
    Rails.logger.expects(:info).with("Trusted Types violation: sink=Element innerHTML source=/assets/turbo.min.js:5:11182 route=cards#show")
    Rails.logger.expects(:info).with(regexp_matches(/SYNTHETIC/)).never

    post trusted_types_reports_path(script_name: nil), params: report, headers: { "Content-Type" => "application/csp-report" }

    assert_response :no_content
  end

  test "accepts and ignores anything else" do
    Rails.logger.stubs(:info)
    Rails.logger.expects(:info).with(regexp_matches(/Trusted Types/)).never

    post trusted_types_reports_path(script_name: nil), params: "nonsense", headers: { "Content-Type" => "application/csp-report" }

    assert_response :no_content
  end

  test "refuses other content types, which Rails would parse and log as params" do
    post trusted_types_reports_path(script_name: nil), params: report, headers: { "Content-Type" => "application/json" }

    assert_response :not_found
  end

  private
    def report
      { "csp-report" => {
          "effective-directive" => "require-trusted-types-for",
          "script-sample" => "Element innerHTML|<p>SYNTHETIC private text</p>",
          "source-file" => "http://www.example.com/assets/turbo.min.js",
          "line-number" => 5,
          "column-number" => 11182,
          "document-uri" => "http://www.example.com/#{accounts("37s").external_account_id}/cards/1"
        } }.to_json
    end
end
