require "test_helper"

class Identity::AccessTokenTest < ActiveSupport::TestCase
  test "only one session at the time" do
    assert_changes -> { Session.count }, +1 do
      identity_access_tokens(:jasons_api_token).session
    end

    assert_no_changes -> { Session.count } do
      identity_access_tokens(:jasons_api_token).session
    end
  end
end
