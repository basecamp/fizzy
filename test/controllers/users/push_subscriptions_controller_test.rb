require "test_helper"

class Users::PushSubscriptionsControllerTest < ActionDispatch::IntegrationTest
  PUBLIC_TEST_IP = "142.250.185.206"

  setup do
    sign_in_as :david
    stub_dns_resolution(PUBLIC_TEST_IP)
  end

  test "create new push subscription" do
    subscription_params = { "endpoint" => "https://fcm.googleapis.com/fcm/send/abc123", "p256dh_key" => "123", "auth_key" => "456" }

    post user_push_subscriptions_path(users(:david)),
      params: { push_subscription: subscription_params }, headers: { "HTTP_USER_AGENT" => "Mozilla/5.0" }

    assert_response :no_content

    assert_equal subscription_params, users(:david).push_subscriptions.last.attributes.slice("endpoint", "p256dh_key", "auth_key")
    assert_equal "Mozilla/5.0", users(:david).push_subscriptions.last.user_agent
  end

  test "destroy a push subscription" do
    subscription = users(:david).push_subscriptions.create!(
      endpoint: "https://fcm.googleapis.com/fcm/send/abc123",
      p256dh_key: "123",
      auth_key: "456"
    )

    assert_difference -> { Push::Subscription.count }, -1 do
      delete user_push_subscription_path(users(:david), subscription)
      assert_redirected_to user_push_subscriptions_path(users(:david))
    end
  end

  test "rejects subscription with non-permitted endpoint" do
    subscription_params = { "endpoint" => "https://attacker.example.com/steal", "p256dh_key" => "123", "auth_key" => "456" }

    assert_no_difference -> { Push::Subscription.count } do
      post user_push_subscriptions_path(users(:david)),
        params: { push_subscription: subscription_params }
    end

    assert_response :unprocessable_entity
  end

  test "rejects subscription with endpoint resolving to private IP" do
    stub_dns_resolution("192.168.1.1")

    subscription_params = { "endpoint" => "https://fcm.googleapis.com/fcm/send/abc123", "p256dh_key" => "123", "auth_key" => "456" }

    assert_no_difference -> { Push::Subscription.count } do
      post user_push_subscriptions_path(users(:david)),
        params: { push_subscription: subscription_params }
    end

    assert_response :unprocessable_entity
  end

  private
    def stub_dns_resolution(*ips)
      dns_mock = mock("dns")
      dns_mock.stubs(:each_address).multiple_yields(*ips)
      Resolv::DNS.stubs(:open).yields(dns_mock)
    end
end
