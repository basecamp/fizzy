require "test_helper"

class Session::DevicesTest < ActiveSupport::TestCase
  setup do
    @session = sessions(:david)
    @identity = @session.identity
  end

  test "destroying session destroys associated devices" do
    device = ApplicationPushDevice.register(
      session: @session,
      token: "test_token",
      platform: "apple",
      name: "Test iPhone"
    )

    assert_difference -> { ApplicationPushDevice.count }, -1 do
      @session.destroy
    end

    assert_nil ApplicationPushDevice.find_by(id: device.id)
  end

  test "destroying session does not destroy devices from other sessions" do
    other_session = sessions(:kevin)

    device = ApplicationPushDevice.register(
      session: other_session,
      token: "other_token",
      platform: "apple",
      name: "Other iPhone"
    )

    assert_no_difference -> { ApplicationPushDevice.count } do
      @session.destroy
    end

    assert ApplicationPushDevice.exists?(device.id)
  end
end
