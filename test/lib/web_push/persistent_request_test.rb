require "test_helper"

class WebPush::PersistentRequestTest < ActiveSupport::TestCase
  ENDPOINT = "https://fcm.googleapis.com/fcm/send/test123"

  test "pins connection to endpoint_ip" do
    request = stub_request(:post, ENDPOINT)
      .with(ipaddr: DnsTestHelper::WEB_PUSH_PUBLIC_TEST_IP)
      .to_return(status: 201)

    pinned_notification.deliver

    assert_requested request
  end

  test "connects to endpoint_ip even when a proxy is configured" do
    saved = ENV.slice("http_proxy", "https_proxy", "HTTP_PROXY", "HTTPS_PROXY", "no_proxy", "NO_PROXY")
    %w[ no_proxy NO_PROXY ].each { |key| ENV.delete(key) }
    %w[ http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ].each { |key| ENV[key] = "http://proxy.internal:3128" }

    TCPSocket.expects(:open).with { |*args, **| args.first == "proxy.internal" }.never
    TCPSocket.expects(:open).with { |*args, **| args.first == DnsTestHelper::WEB_PUSH_PUBLIC_TEST_IP && args[1] == 443 }.throws(:not_proxied)

    assert_throws :not_proxied do
      pinned_notification.deliver
    end
  ensure
    %w[ http_proxy https_proxy HTTP_PROXY HTTPS_PROXY no_proxy NO_PROXY ].each { |key| ENV.delete(key) }
    saved.each { |key, value| ENV[key] = value }
  end

  private
    def pinned_notification
      WebPush::Notification.new(
        title: "Test",
        body: "Test notification",
        url: "/test",
        badge: 0,
        endpoint: ENDPOINT,
        endpoint_ip: DnsTestHelper::WEB_PUSH_PUBLIC_TEST_IP,
        p256dh_key: "BNcRdreALRFXTkOOUHK1EtK2wtaz5Ry4YfYCA_0QTpQtUbVlUls0VJXg7A8u-Ts1XbjhazAkj7I99e8QcYP7DkM",
        auth_key: "tBHItJI5svbpez7KI4CCXg"
      )
    end
end
