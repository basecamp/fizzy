require "test_helper"

class Users::DevicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:david)
    sign_in_as @user
  end

  # === Index (Web) ===

  test "index shows user devices" do
    skip "Implement in Phase 4"
  end

  test "index requires authentication" do
    skip "Implement in Phase 4"
  end

  # === Create (API) ===

  test "creates a new device via api" do
    skip "Implement in Phase 4"
  end

  test "updates existing device with same token" do
    skip "Implement in Phase 4"
  end

  test "rejects invalid platform" do
    skip "Implement in Phase 4"
  end

  test "create requires authentication" do
    skip "Implement in Phase 4"
  end

  # === Destroy (Web) ===

  test "destroys device via web" do
    skip "Implement in Phase 4"
  end

  test "cannot destroy another user's device" do
    skip "Implement in Phase 4"
  end

  test "destroy requires authentication" do
    skip "Implement in Phase 4"
  end
end
