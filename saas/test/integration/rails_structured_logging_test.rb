require "test_helper"

class RailsStructuredLoggingTest < ActiveSupport::TestCase
  test "request serializer filters internal params" do
    request = ActionDispatch::Request.new(
      "REQUEST_METHOD" => "GET",
      "PATH_INFO" => "/test",
      "QUERY_STRING" => "",
      "SERVER_NAME" => "localhost",
      "SERVER_PORT" => "3000",
      "HTTP_HOST" => "www.example.com",
      "HTTP_ACCEPT" => "*/*",
      "rack.url_scheme" => "https"
    )

    now = Time.now
    event = ActiveSupport::Notifications::Event.new(
      "process_action.action_controller", now, now, SecureRandom.hex(10),
      {
        request: request,
        controller: "TestController",
        action: "index",
        format: "html",
        params: { "controller" => "TestController", "action" => "index", "id" => "1" }
      }
    )

    json = RailsStructuredLogging::Serializers::Elastic::RequestSerializer.serialize(event, "")
    data = JSON.parse(json)

    serialized_params = JSON.parse(data.dig("http", "request", "parameters"))
    assert_equal({ "id" => "1" }, serialized_params)
  end
end
