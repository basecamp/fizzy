require "test_helper"

class FlatJsonParamsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "update user role with flat JSON" do
    put user_role_path(users(:david)), params: { role: "admin" }, as: :json

    assert_response :no_content
    assert users(:david).reload.admin?
  end

  test "update notification settings with flat JSON" do
    logout_and_sign_in_as :david

    assert_changes -> { users(:david).reload.settings.bundle_email_frequency }, from: "never", to: "every_few_hours" do
      put notifications_settings_path, params: { bundle_email_frequency: "every_few_hours" }, as: :json
    end

    assert_response :no_content
  end

  test "update join code with flat JSON" do
    put account_join_code_path, params: { usage_limit: 5 }, as: :json

    assert_response :no_content
    assert_equal 5, Current.account.join_code.reload.usage_limit
  end

  test "update account settings with flat JSON" do
    put account_settings_path, params: { name: "New Name" }, as: :json

    assert_response :no_content
    assert_equal "New Name", Current.account.reload.name
  end

  test "update board entropy with flat JSON" do
    board = boards(:writebook)

    put board_entropy_path(board), params: { auto_postpone_period: 99.days }, as: :json

    assert_response :no_content
    assert_equal 99.days, board.entropy.reload.auto_postpone_period
  end

  test "update account entropy with flat JSON" do
    put account_entropy_path, params: { auto_postpone_period: 2.days }, as: :json

    assert_response :no_content
    assert_equal 2.days, Current.account.entropy.reload.auto_postpone_period
  end

  test "create push subscription with flat JSON" do
    stub_dns_resolution("142.250.185.206")

    post user_push_subscriptions_path(users(:kevin)),
      params: { endpoint: "https://fcm.googleapis.com/fcm/send/abc123", p256dh_key: "key1", auth_key: "key2" },
      as: :json

    assert_response :created
  end

  private
    def stub_dns_resolution(*ips)
      dns_mock = mock("dns")
      dns_mock.stubs(:each_address).multiple_yields(*ips)
      Resolv::DNS.stubs(:open).yields(dns_mock)
    end
end
