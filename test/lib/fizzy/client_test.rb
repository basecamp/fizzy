require "test_helper"
require_relative "../../../cli/lib/fizzy/client"

class FizzyClientTest < ActiveSupport::TestCase
  Response = Struct.new(:code, :body, :headers) do
    def [](key)
      headers[key]
    end
  end

  test "request sends JSON and bearer token" do
    response = Response.new("200", '{"ok":true}', { "Content-Type" => "application/json" })
    http = mock("http")
    http.expects(:request).with do |request|
      assert_equal "Bearer secret", request["Authorization"]
      assert_equal "application/json", request["Content-Type"]
      assert_equal({ "name" => "Agent" }, JSON.parse(request.body))
      true
    end.returns(response)
    Net::HTTP.expects(:start).with("app.example.test", 443, use_ssl: true).yields(http).returns(response)

    client = Fizzy::Client.new(base_url: "https://app.example.test", token: "secret")
    payload = client.request(:post, "/boards", params: { name: "Agent" })

    assert_equal({ "ok" => true }, payload)
  end

  test "request raises api error with parsed JSON body" do
    response = Response.new("422", '{"message":"Nope"}', { "Content-Type" => "application/json" })
    http = stub(request: response)
    Net::HTTP.stubs(:start).yields(http).returns(response)

    error = assert_raises(Fizzy::ApiError) do
      Fizzy::Client.new(base_url: "https://app.example.test").request(:get, "/bad")
    end

    assert_equal 422, error.status
    assert_equal({ "message" => "Nope" }, error.body)
    assert_match "HTTP 422: Nope", error.message
  end

  test "request returns raw string for non-json response" do
    response = Response.new("200", "plain text", { "Content-Type" => "text/plain" })
    http = stub(request: response)
    Net::HTTP.stubs(:start).yields(http).returns(response)

    payload = Fizzy::Client.new(base_url: "https://app.example.test").request(:get, "/plain")

    assert_equal "plain text", payload
  end
end
