require "test_helper"

class Fizzy::Saas::ClientGeoLoggingTest < ActionDispatch::IntegrationTest
  CLOUDFLARE_HEADERS = {
    "CF-IPCountry" => "BR",
    "CF-Region-Code" => "SP",
    "CF-IPCity" => "São Paulo".b,
    "CF-IPLatitude" => "-23.54750",
    "CF-IPLongitude" => "-46.63611"
  }

  test "logs where the request comes from, from Cloudflare's visitor location headers" do
    geo = logged_client_geo(headers: CLOUDFLARE_HEADERS)

    assert_equal({ "country_iso_code" => "BR", "region_iso_code" => "SP", "city_name" => "São Paulo",
      "location" => { "lat" => -23.5475, "lon" => -46.63611 } }, geo)
  end

  test "logs only the country when Cloudflare sends only the country" do
    assert_equal({ "country_iso_code" => "BR" }, logged_client_geo(headers: { "CF-IPCountry" => "BR" }))
  end

  test "leaves out a location that is missing a coordinate or isn't a number" do
    assert_nil logged_client_geo(headers: CLOUDFLARE_HEADERS.except("CF-IPLongitude"))["location"]
    assert_nil logged_client_geo(headers: CLOUDFLARE_HEADERS.merge("CF-IPLatitude" => "nowhere"))["location"]
  end

  test "leaves out a location that overflows or is out of range, and still logs the request" do
    assert_nil logged_client_geo(headers: CLOUDFLARE_HEADERS.merge("CF-IPLatitude" => "1e999"))["location"]
    assert_nil logged_client_geo(headers: CLOUDFLARE_HEADERS.merge("CF-IPLongitude" => "-1e999"))["location"]
    assert_nil logged_client_geo(headers: CLOUDFLARE_HEADERS.merge("CF-IPLatitude" => "91"))["location"]
    assert_nil logged_client_geo(headers: CLOUDFLARE_HEADERS.merge("CF-IPLongitude" => "180.5"))["location"]
  end

  test "logs no geo without Cloudflare's headers" do
    assert_nil logged_client_geo(headers: {})
  end

  private
    def logged_client_geo(headers:)
      lines = structured_log_lines { untenanted { get new_session_path, headers: headers } }
      assert_response :success

      request_line = lines.map { |line| JSON.parse(line) }.find { |line| line.dig("rails", "controller") == "SessionsController" }
      assert request_line, "expected the request's structured log line"
      assert request_line.dig("client", "ip"), "geo should sit beside the client IP, not replace it"
      request_line.dig("client", "geo")
    end

    def structured_log_lines
      lines = []
      Rails.application.config.structured_logging.logger.stubs(:info).with { |line| lines << line }
      yield
      lines
    end
end
