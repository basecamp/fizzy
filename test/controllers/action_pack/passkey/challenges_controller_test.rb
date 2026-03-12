require "test_helper"

class ActionPack::Passkey::ChallengesControllerTest < ActionDispatch::IntegrationTest
  test "returns a fresh challenge" do
    untenanted do
      post passkey_challenge_url

      assert_response :success
      assert_not_nil response.parsed_body["challenge"]
    end
  end

  test "stores challenge in session" do
    untenanted do
      post passkey_challenge_url

      assert_equal response.parsed_body["challenge"], session[:webauthn_challenge]
    end
  end

  test "returns a different challenge each time" do
    untenanted do
      post passkey_challenge_url
      first_challenge = response.parsed_body["challenge"]

      post passkey_challenge_url
      second_challenge = response.parsed_body["challenge"]

      assert_not_equal first_challenge, second_challenge
    end
  end
end
