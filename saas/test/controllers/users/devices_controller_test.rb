require "test_helper"

class Users::DevicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:david)
    sign_in_as @user
  end

  # === Index (Web) ===

  test "index shows user devices" do
    @user.devices.create!(token: "test_token_123", platform: "apple", name: "iPhone 15 Pro")

    get users_devices_path

    assert_response :success
    assert_select "strong", "iPhone 15 Pro"
    assert_select "li", /iOS/
  end

  test "index shows empty state when no devices" do
    @user.devices.delete_all

    get users_devices_path

    assert_response :success
    assert_select "p", /No devices registered/
  end

  test "index requires authentication" do
    sign_out

    get users_devices_path

    assert_response :redirect
  end

  # === Create (API) ===

  test "creates a new device via api" do
    token = SecureRandom.hex(32)

    assert_difference "ActionPushNative::Device.count", 1 do
      post users_devices_path, params: {
        token: token,
        platform: "apple",
        name: "iPhone 15 Pro"
      }, as: :json
    end

    assert_response :created

    device = ActionPushNative::Device.last
    assert_equal token, device.token
    assert_equal "apple", device.platform
    assert_equal "iPhone 15 Pro", device.name
    assert_equal @user, device.owner
  end

  test "creates android device" do
    post users_devices_path, params: {
      token: SecureRandom.hex(32),
      platform: "google",
      name: "Pixel 8"
    }, as: :json

    assert_response :created

    device = ActionPushNative::Device.last
    assert_equal "google", device.platform
  end

  test "same token can be registered by multiple users" do
    shared_token = "shared_push_token_123"
    other_user = users(:kevin)

    # Other user registers the token first
    other_device = other_user.devices.create!(
      token: shared_token,
      platform: "apple",
      name: "Kevin's iPhone"
    )

    # Current user registers the same token with their own device
    assert_difference "ActionPushNative::Device.count", 1 do
      post users_devices_path, params: {
        token: shared_token,
        platform: "apple",
        name: "David's iPhone"
      }, as: :json
    end

    assert_response :created

    # Both users have their own device records
    assert_equal shared_token, other_device.reload.token
    assert_equal other_user, other_device.owner

    davids_device = @user.devices.last
    assert_equal shared_token, davids_device.token
    assert_equal @user, davids_device.owner
  end

  test "rejects invalid platform" do
    post users_devices_path, params: {
      token: SecureRandom.hex(32),
      platform: "windows",
      name: "Surface"
    }, as: :json

    assert_response :bad_request
  end

  test "rejects missing token" do
    post users_devices_path, params: {
      platform: "apple",
      name: "iPhone"
    }, as: :json

    assert_response :bad_request
  end

  test "create requires authentication" do
    sign_out

    post users_devices_path, params: {
      token: SecureRandom.hex(32),
      platform: "apple"
    }, as: :json

    assert_response :redirect
  end

  # === Destroy (Web) ===

  test "destroys device by id" do
    device = @user.devices.create!(
      token: "token_to_delete",
      platform: "apple",
      name: "iPhone"
    )

    assert_difference "ActionPushNative::Device.count", -1 do
      delete users_device_path(device)
    end

    assert_redirected_to users_devices_path
    assert_not ActionPushNative::Device.exists?(device.id)
  end

  test "does nothing when device not found by id" do
    assert_no_difference "ActionPushNative::Device.count" do
      delete users_device_path(id: "nonexistent")
    end

    assert_redirected_to users_devices_path
  end

  test "cannot destroy another user's device by id" do
    other_user = users(:kevin)
    device = other_user.devices.create!(
      token: "other_users_token",
      platform: "apple",
      name: "Other iPhone"
    )

    assert_no_difference "ActionPushNative::Device.count" do
      delete users_device_path(device)
    end

    assert_redirected_to users_devices_path
    assert ActionPushNative::Device.exists?(device.id)
  end

  test "destroy by id requires authentication" do
    device = @user.devices.create!(
      token: "my_token",
      platform: "apple",
      name: "iPhone"
    )

    sign_out

    delete users_device_path(device)

    assert_response :redirect
    assert ActionPushNative::Device.exists?(device.id)
  end

  # === Destroy by Token (API) ===

  test "destroys device by token" do
    device = @user.devices.create!(
      token: "token_to_unregister",
      platform: "apple",
      name: "iPhone"
    )

    assert_difference "ActionPushNative::Device.count", -1 do
      delete unregister_users_devices_path, params: { token: "token_to_unregister" }, as: :json
    end

    assert_response :no_content
    assert_not ActionPushNative::Device.exists?(device.id)
  end

  test "does nothing when device not found by token" do
    assert_no_difference "ActionPushNative::Device.count" do
      delete unregister_users_devices_path, params: { token: "nonexistent_token" }, as: :json
    end

    assert_response :no_content
  end

  test "cannot destroy another user's device by token" do
    other_user = users(:kevin)
    device = other_user.devices.create!(
      token: "other_users_token",
      platform: "apple",
      name: "Other iPhone"
    )

    assert_no_difference "ActionPushNative::Device.count" do
      delete unregister_users_devices_path, params: { token: "other_users_token" }, as: :json
    end

    assert_response :no_content
    assert ActionPushNative::Device.exists?(device.id)
  end

  test "destroy by token requires authentication" do
    device = @user.devices.create!(
      token: "my_token",
      platform: "apple",
      name: "iPhone"
    )

    sign_out

    delete unregister_users_devices_path, params: { token: "my_token" }, as: :json

    assert_response :redirect
    assert ActionPushNative::Device.exists?(device.id)
  end
end
