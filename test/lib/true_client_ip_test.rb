require "test_helper"

class TrackTrueClientIpTest < ActiveSupport::TestCase
  setup do
    @app = ->(env) { [ 200, {}, [ "OK" ] ] }
    @middleware = TrackTrueClientIp.new(@app)
  end

  test "sets X-Forwarded-For header when True-Client-IP header is present" do
    env = { "HTTP_TRUE_CLIENT_IP" => "123.123.123.123" }
    @middleware.call(env)
    assert_equal "123.123.123.123", env["HTTP_X_FORWARDED_FOR"]
  end

  test "does not modify environment when True-Client-IP header is absent" do
    env = {}
    @middleware.call(env)
    assert_nil env["HTTP_X_FORWARDED_FOR"]

    env = { "HTTP_X_FORWARDED_FOR" => "234.234.234.234" }
    @middleware.call(env)
    assert_equal "234.234.234.234", env["HTTP_X_FORWARDED_FOR"]
  end

  test "calls the next middleware in the stack" do
    called = false
    app = ->(env) { called = true; [ 200, {}, [ "OK" ] ] }
    middleware = TrackTrueClientIp.new(app)

    middleware.call({})

    assert called
  end
end
