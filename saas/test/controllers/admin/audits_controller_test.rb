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

  test "valid bearer token is allowed" do
    token = Audits1984::AuditorToken.generate_for(identities(:david))

    untenanted do
      get saas.admin_audits1984_path, headers: { "Authorization" => "Bearer #{token}" }
    end

    assert_response :success
  end

  test "expired bearer token is forbidden" do
    token = Audits1984::AuditorToken.generate_for(identities(:david))
    Audits1984::AuditorToken.update_all(expires_at: 1.day.ago)

    untenanted do
      get saas.admin_audits1984_path, headers: { "Authorization" => "Bearer #{token}" }
    end

    assert_response :unauthorized
  end

  test "bearer token for non-staff user is forbidden" do
    # Even with a valid token, non-staff users should be denied access.
    # This handles the case where a user's staff privileges are revoked
    # after a token was issued.
    token = Audits1984::AuditorToken.generate_for(identities(:jz))

    untenanted do
      get saas.admin_audits1984_path, headers: { "Authorization" => "Bearer #{token}" }
    end

    assert_response :forbidden
  end
end
