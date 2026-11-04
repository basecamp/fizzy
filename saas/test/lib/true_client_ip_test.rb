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

  test "True-Client-IP decides the remote IP over a client-sent Forwarded header" do
    remote_ip = nil
    app = ->(env) { remote_ip = ActionDispatch::Request.new(env).remote_ip; [ 200, {}, [ "OK" ] ] }
    middleware = TrackTrueClientIp.new(ActionDispatch::RemoteIp.new(app))

    middleware.call("REMOTE_ADDR" => "10.0.0.1", "HTTP_TRUE_CLIENT_IP" => "123.123.123.123", "HTTP_FORWARDED" => "for=9.9.9.9")

    assert_equal "123.123.123.123", remote_ip
  end

  test "calls the next middleware in the stack" do
    called = false
    app = ->(env) { called = true; [ 200, {}, [ "OK" ] ] }
    middleware = TrackTrueClientIp.new(app)

    middleware.call({})

    assert called
  end
end
