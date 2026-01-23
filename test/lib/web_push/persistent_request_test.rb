require "test_helper"

class WebPush::PersistentRequestTest < ActiveSupport::TestCase
  PUBLIC_TEST_IP = "142.250.185.206"
  ENDPOINT = "https://fcm.googleapis.com/fcm/send/test123"

  test "pins connection to endpoint_ip" do
    request = stub_request(:post, ENDPOINT)
      .with(ipaddr: PUBLIC_TEST_IP)
      .to_return(status: 201)

    notification = WebPush::Notification.new(
      title: "Test",
      body: "Test notification",
      url: "/test",
      badge: 0,
      endpoint: ENDPOINT,
      endpoint_ip: PUBLIC_TEST_IP,
      p256dh_key: "BNcRdreALRFXTkOOUHK1EtK2wtaz5Ry4YfYCA_0QTpQtUbVlUls0VJXg7A8u-Ts1XbjhazAkj7I99e8QcYP7DkM",
      auth_key: "tBHItJI5svbpez7KI4CCXg"
    )
    notification.deliver

    assert_requested request
  end
end
