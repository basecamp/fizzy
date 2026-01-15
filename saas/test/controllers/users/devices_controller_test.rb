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
    token = SecureRandom.hex(32)

    post users_devices_path, params: {
      token: token,
      platform: "google",
      name: "Pixel 8"
    }, as: :json

    assert_response :created

    device = ActionPushNative::Device.last
    assert_equal "google", device.platform
  end

  test "updates existing device with same token" do
    existing_device = @user.devices.create!(
      token: "existing_token_123",
      platform: "apple",
      name: "Old iPhone"
    )

    assert_no_difference "ActionPushNative::Device.count" do
      post users_devices_path, params: {
        token: "existing_token_123",
        platform: "apple",
        name: "New iPhone"
      }, as: :json
    end

    assert_response :created
    assert_equal "New iPhone", existing_device.reload.name
  end

  test "reassigns device token from another user" do
    other_user = users(:kevin)
    device = other_user.devices.create!(
      token: "shared_token_123",
      platform: "apple",
      name: "Other iPhone"
    )

    assert_no_difference "ActionPushNative::Device.count" do
      post users_devices_path, params: {
        token: "shared_token_123",
        platform: "apple",
        name: "My iPhone"
      }, as: :json
    end

    assert_response :created
    assert_equal @user, device.reload.owner
    assert_equal "My iPhone", device.name
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

  test "destroys device" do
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

  test "does nothing when device not found" do
    assert_no_difference "ActionPushNative::Device.count" do
      delete users_device_path(id: "nonexistent")
    end

    assert_redirected_to users_devices_path
  end

  test "cannot destroy another user's device" do
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

  test "destroy requires authentication" do
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
end
