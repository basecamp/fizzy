require "test_helper"

class Admin::MissionControlTest < ActionDispatch::IntegrationTest
  test "staff can access mission control jobs" do
    sign_in_as :david

    untenanted do
      get "/admin/jobs"
    end

    assert_response :success
  end

  test "non-staff cannot access mission control jobs" do
    sign_in_as :jz

    untenanted do
      get "/admin/jobs"
    end

    assert_response :forbidden
  end
end
