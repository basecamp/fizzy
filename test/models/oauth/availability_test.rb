require "test_helper"

class Oauth::AvailabilityTest < ActiveSupport::TestCase
  include OauthAvailabilityTestHelper

  test "lit in test" do
    assert Oauth::Availability.acceptance_enabled?
    assert Oauth::Availability.issuance_enabled?
  end

  test "an unset acceptance switch is dark" do
    with_oauth_availability acceptance: nil, issuance: nil do
      assert_not Oauth::Availability.acceptance_enabled?
      assert_not Oauth::Availability.issuance_enabled?
    end
  end

  test "acceptance must be exactly true" do
    with_oauth_availability acceptance: "false" do
      assert_not Oauth::Availability.acceptance_enabled?
    end
  end

  test "issuance follows acceptance unless paused" do
    with_oauth_availability acceptance: true, issuance: nil do
      assert Oauth::Availability.issuance_enabled?
    end

    with_oauth_availability acceptance: true, issuance: false do
      assert Oauth::Availability.acceptance_enabled?
      assert_not Oauth::Availability.issuance_enabled?
    end
  end

  test "issuance is subordinate to acceptance" do
    with_oauth_availability acceptance: false, issuance: true do
      assert_not Oauth::Availability.issuance_enabled?
    end
  end

  test "a pilot client clears both switches, and only by its exact client_id" do
    with_oauth_availability acceptance: false, issuance: false, pilot_client_ids: [ "pilot_1" ] do
      assert Oauth::Availability.acceptance_enabled?("pilot_1")
      assert Oauth::Availability.issuance_enabled?("pilot_1")

      assert_not Oauth::Availability.acceptance_enabled?
      assert_not Oauth::Availability.issuance_enabled?("pilot_2")
      assert_not Oauth::Availability.issuance_enabled?("PILOT_1")
      assert_not Oauth::Availability.issuance_enabled?([ "pilot_1" ])
      assert_not Oauth::Availability.issuance_enabled?("")
    end
  end
end
