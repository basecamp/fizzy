require "test_helper"

class Oauth::RedeemedAuthorizationCodeTest < ActiveSupport::TestCase
  test "a jti is recorded once" do
    Oauth::RedeemedAuthorizationCode.create!(jti: "a5f1c0de-0000-4000-8000-000000000001")

    assert_raises(ActiveRecord::RecordNotUnique) do
      Oauth::RedeemedAuthorizationCode.create!(jti: "a5f1c0de-0000-4000-8000-000000000001")
    end
  end

  test "cleanup keeps records well past the code's lifetime, then removes them" do
    kept = travel_to(24.hours.ago) { Oauth::RedeemedAuthorizationCode.create!(jti: "a5f1c0de-0000-4000-8000-000000000002") }
    stale = travel_to(26.hours.ago) { Oauth::RedeemedAuthorizationCode.create!(jti: "a5f1c0de-0000-4000-8000-000000000003") }

    Oauth::RedeemedAuthorizationCode.cleanup

    assert Oauth::RedeemedAuthorizationCode.exists?(kept.id)
    assert_not Oauth::RedeemedAuthorizationCode.exists?(stale.id)
  end
end
