require "test_helper"

class Push::SubscriptionTest < ActiveSupport::TestCase
  PUBLIC_TEST_IP = "142.250.185.206" # google.com IP

  setup do
    stub_dns_resolution(PUBLIC_TEST_IP)
  end

  test "valid subscription with permitted endpoint" do
    subscription = Push::Subscription.new(
      user: users(:david),
      endpoint: "https://fcm.googleapis.com/fcm/send/abc123",
      p256dh_key: "test_key",
      auth_key: "test_auth"
    )

    assert subscription.valid?
  end

  test "rejects endpoint with non-https scheme" do
    subscription = Push::Subscription.new(
      user: users(:david),
      endpoint: "http://fcm.googleapis.com/fcm/send/abc123",
      p256dh_key: "test_key",
      auth_key: "test_auth"
    )

    assert_not subscription.valid?
    assert_includes subscription.errors[:endpoint], "must use HTTPS"
  end

  test "rejects endpoint with non-permitted host" do
    subscription = Push::Subscription.new(
      user: users(:david),
      endpoint: "https://attacker.example.com/webhook",
      p256dh_key: "test_key",
      auth_key: "test_auth"
    )

    assert_not subscription.valid?
    assert_includes subscription.errors[:endpoint], "is not a permitted push service"
  end

  test "rejects endpoint that resolves to private IP" do
    stub_dns_resolution("192.168.1.1")

    subscription = Push::Subscription.new(
      user: users(:david),
      endpoint: "https://fcm.googleapis.com/fcm/send/abc123",
      p256dh_key: "test_key",
      auth_key: "test_auth"
    )

    assert_not subscription.valid?
    assert_includes subscription.errors[:endpoint], "resolves to a private or invalid IP address"
  end

  test "rejects endpoint that resolves to loopback IP" do
    stub_dns_resolution("127.0.0.1")

    subscription = Push::Subscription.new(
      user: users(:david),
      endpoint: "https://fcm.googleapis.com/fcm/send/abc123",
      p256dh_key: "test_key",
      auth_key: "test_auth"
    )

    assert_not subscription.valid?
    assert_includes subscription.errors[:endpoint], "resolves to a private or invalid IP address"
  end

  test "rejects endpoint that resolves to link-local IP (AWS IMDS)" do
    stub_dns_resolution("169.254.169.254")

    subscription = Push::Subscription.new(
      user: users(:david),
      endpoint: "https://fcm.googleapis.com/fcm/send/abc123",
      p256dh_key: "test_key",
      auth_key: "test_auth"
    )

    assert_not subscription.valid?
    assert_includes subscription.errors[:endpoint], "resolves to a private or invalid IP address"
  end

  test "resolved_endpoint_ip returns pinned public IP" do
    subscription = Push::Subscription.new(
      user: users(:david),
      endpoint: "https://fcm.googleapis.com/fcm/send/abc123",
      p256dh_key: "test_key",
      auth_key: "test_auth"
    )

    assert_equal PUBLIC_TEST_IP, subscription.resolved_endpoint_ip
  end

  test "accepts all permitted push service domains" do
    permitted_endpoints = [
      "https://fcm.googleapis.com/fcm/send/token123",
      "https://jmt17.google.com/fcm/send/token123",
      "https://updates.push.services.mozilla.com/wpush/v2/token123",
      "https://web.push.apple.com/QaBC123",
      "https://wns2-db5p.notify.windows.com/w/?token=abc123"
    ]

    permitted_endpoints.each do |endpoint|
      subscription = Push::Subscription.new(
        user: users(:david),
        endpoint: endpoint,
        p256dh_key: "test_key",
        auth_key: "test_auth"
      )

      assert subscription.valid?, "Expected #{endpoint} to be valid, got errors: #{subscription.errors.full_messages}"
    end
  end

  private
    def stub_dns_resolution(*ips)
      dns_mock = mock("dns")
      dns_mock.stubs(:each_address).multiple_yields(*ips)
      Resolv::DNS.stubs(:open).yields(dns_mock)
    end
end
