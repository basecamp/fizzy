require "test_helper"

class Admin::AuditsControllerTest < ActionDispatch::IntegrationTest
  # Test authentication via the Audits1984::SessionsController#index endpoint,
  # which inherits from Admin::AuditsController through Audits1984::ApplicationController.

  test "unauthenticated access is forbidden" do
    untenanted do
      get saas.admin_audits1984_path
      assert_redirected_to new_session_path
    end
  end

  test "logged-in non-staff access is forbidden" do
    sign_in_as :jz

    untenanted do
      get saas.admin_audits1984_path
    end

    assert_response :forbidden
  end

  test "logged-in staff access is allowed" do
    sign_in_as :david

    untenanted do
      get saas.admin_audits1984_path
    end

    assert_response :success
  end

  test "invalid bearer token is forbidden" do
    untenanted do
      get saas.admin_audits1984_path, headers: { "Authorization" => "Bearer invalid_token" }
    end

    assert_response :unauthorized
  end
end
