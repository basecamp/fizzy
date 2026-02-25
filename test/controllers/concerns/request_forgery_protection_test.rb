require "test_helper"

class RequestForgeryProtectionTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin

    @original_allow_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    @original_force_ssl = Rails.configuration.force_ssl
    @original_secure_protocol = ActionDispatch::Http::URL.secure_protocol
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @original_allow_forgery_protection
    Rails.configuration.force_ssl = @original_force_ssl
    ActionDispatch::Http::URL.secure_protocol = @original_secure_protocol
  end

  test "JSON request succeeds with missing Sec-Fetch-Site header" do
    assert_difference -> { Board.count }, +1 do
      post boards_path,
        params: { board: { name: "Test Board" } },
        as: :json
    end

    assert_response :created
  end

  test "HTTP request succeeds with missing Sec-Fetch-Site header when force_ssl is disabled" do
    Rails.configuration.force_ssl = false

    assert_difference -> { Board.count }, +1 do
      post boards_path,
        params: { board: { name: "Test Board" } }
    end

    assert_response :redirect
  end

  test "HTTP request fails with missing Sec-Fetch-Site header when force_ssl is enabled" do
    Rails.configuration.force_ssl = true
    ActionDispatch::Http::URL.secure_protocol = true

    assert_no_difference -> { Board.count } do
      post boards_path,
        params: { board: { name: "Test Board" } }
    end

    assert_response :unprocessable_entity
  end

  test "HTTPS request fails with missing Sec-Fetch-Site header" do
    Rails.configuration.force_ssl = false

    assert_no_difference -> { Board.count } do
      post boards_path,
        params: { board: { name: "Test Board" } },
        headers: { "X-Forwarded-Proto" => "https" }
    end

    assert_response :unprocessable_entity
  end
end
