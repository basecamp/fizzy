require "test_helper"

class DevicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @identity = identities(:david)
    sign_in_as :david
  end

  test "index shows identity's devices" do
    @identity.devices.create!(token: "test_token_123", platform: "apple", name: "iPhone 15 Pro")

    get devices_path

    assert_response :success
    assert_select "strong", "iPhone 15 Pro"
    assert_select "li", /iOS/
  end

  test "index shows empty state when no devices" do
    @identity.devices.delete_all

    get devices_path

    assert_response :success
    assert_select "p", /No devices registered/
  end

  test "index requires authentication" do
    sign_out

    get devices_path

    assert_response :redirect
  end

  test "creates a new device via api" do
    token = SecureRandom.hex(32)

    assert_difference -> { ApplicationPushDevice.count }, 1 do
      post devices_path, params: {
        token: token,
        platform: "apple",
        name: "iPhone 15 Pro"
      }, as: :json
    end

    assert_response :created

    device = ApplicationPushDevice.last
    assert_equal token, device.token
    assert_equal "apple", device.platform
    assert_equal "iPhone 15 Pro", device.name
    assert_equal @identity, device.owner
  end

  test "creates android device" do
    post devices_path, params: {
      token: SecureRandom.hex(32),
      platform: "google",
      name: "Pixel 8"
    }, as: :json

    assert_response :created

    device = ApplicationPushDevice.last
    assert_equal "google", device.platform
  end

  test "same token can be registered by multiple identities" do
    shared_token = "shared_push_token_123"
    other_identity = identities(:kevin)

    # Other identity registers the token first
    other_device = other_identity.devices.create!(
      token: shared_token,
      platform: "apple",
      name: "Kevin's iPhone"
    )

    # Current identity registers the same token with their own device
    assert_difference -> { ApplicationPushDevice.count }, 1 do
      post devices_path, params: {
        token: shared_token,
        platform: "apple",
        name: "David's iPhone"
      }, as: :json
    end

    assert_response :created

    # Both identities have their own device records
    assert_equal shared_token, other_device.reload.token
    assert_equal other_identity, other_device.owner

    davids_device = @identity.devices.last
    assert_equal shared_token, davids_device.token
    assert_equal @identity, davids_device.owner
  end

  test "rejects invalid platform" do
    post devices_path, params: {
      token: SecureRandom.hex(32),
      platform: "windows",
      name: "Surface"
    }, as: :json

    assert_response :unprocessable_entity
  end

  test "rejects missing token" do
    post devices_path, params: {
      platform: "apple",
      name: "iPhone"
    }, as: :json

    assert_response :bad_request
  end

  test "create requires authentication" do
    sign_out

    post devices_path, params: {
      token: SecureRandom.hex(32),
      platform: "apple"
    }, as: :json

    assert_response :redirect
  end

  test "destroys device by id" do
    device = @identity.devices.create!(
      token: "token_to_delete",
      platform: "apple",
      name: "iPhone"
    )

    assert_difference -> { ApplicationPushDevice.count }, -1 do
      delete device_path(device)
    end

    assert_redirected_to devices_path
    assert_not ApplicationPushDevice.exists?(device.id)
  end

  test "returns not found when device not found by id" do
    assert_no_difference "ApplicationPushDevice.count" do
      delete device_path(id: "nonexistent")
    end

    assert_response :not_found
  end

  test "returns not found for another identity's device by id" do
    other_identity = identities(:kevin)
    device = other_identity.devices.create!(
      token: "other_identity_token",
      platform: "apple",
      name: "Other iPhone"
    )

    assert_no_difference "ApplicationPushDevice.count" do
      delete device_path(device)
    end

    assert_response :not_found
    assert ApplicationPushDevice.exists?(device.id)
  end

  test "destroy by id requires authentication" do
    device = @identity.devices.create!(
      token: "my_token",
      platform: "apple",
      name: "iPhone"
    )

    sign_out

    delete device_path(device)

    assert_response :redirect
    assert ApplicationPushDevice.exists?(device.id)
  end

  test "destroys device by token" do
    device = @identity.devices.create!(
      token: "token_to_unregister",
      platform: "apple",
      name: "iPhone"
    )

    assert_difference -> { ApplicationPushDevice.count }, -1 do
      delete device_path("token_to_unregister"), as: :json
    end

    assert_response :no_content
    assert_not ApplicationPushDevice.exists?(device.id)
  end

  test "returns not found when device not found by token" do
    assert_no_difference "ApplicationPushDevice.count" do
      delete device_path("nonexistent_token"), as: :json
    end

    assert_response :not_found
  end

  test "returns not found for another identity's device by token" do
    other_identity = identities(:kevin)
    device = other_identity.devices.create!(
      token: "other_identity_token",
      platform: "apple",
      name: "Other iPhone"
    )

    assert_no_difference "ApplicationPushDevice.count" do
      delete device_path("other_identity_token"), as: :json
    end

    assert_response :not_found
    assert ApplicationPushDevice.exists?(device.id)
  end

  test "destroy by token requires authentication" do
    device = @identity.devices.create!(
      token: "my_token",
      platform: "apple",
      name: "iPhone"
    )

    sign_out

    delete device_path("my_token"), as: :json

    assert_response :redirect
    assert ApplicationPushDevice.exists?(device.id)
  end
end
