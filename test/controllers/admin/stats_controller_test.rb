require "test_helper"

class Admin::StatsControllerTest < ActionDispatch::IntegrationTest
  test "staff can access stats" do
    sign_in_as :david

    untenanted do
      get admin_stats_url
    end

    assert_response :success
  end

  test "non-staff cannot access stats" do
    sign_in_as :jz

    untenanted do
      get admin_stats_url
    end

    assert_response :forbidden
  end
end
