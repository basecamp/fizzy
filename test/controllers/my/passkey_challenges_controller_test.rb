require "test_helper"

class My::PasskeyChallengesControllerTest < ActionDispatch::IntegrationTest
  test "returns a fresh challenge" do
    untenanted do
      post my_passkey_challenge_url

      assert_response :success
      assert_not_nil response.parsed_body["challenge"]
    end
  end

  test "stores challenge in cookie" do
    untenanted do
      post my_passkey_challenge_url

      jar = ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash)
      assert_equal response.parsed_body["challenge"], jar.encrypted[ActionPack::Passkey::ChallengesController::COOKIE_NAME]
    end
  end

  test "returns a different challenge each time" do
    untenanted do
      post my_passkey_challenge_url
      first_challenge = response.parsed_body["challenge"]

      post my_passkey_challenge_url
      second_challenge = response.parsed_body["challenge"]

      assert_not_equal first_challenge, second_challenge
    end
  end
end
