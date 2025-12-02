require "test_helper"

class My::AccessTokensControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create new token" do
    get my_access_tokens_path
    assert_response :success

    get new_my_access_token_path
    assert_response :success

    assert_changes -> { identities(:kevin).access_tokens.count }, +1 do
      post my_access_tokens_path, params: { access_token: { description: "GitHub", permission: "read" } }
      follow_redirect!
      assert_in_body identities(:kevin).access_tokens.last.token
    end
  end

  test "accessing new token after reveal window redirects to index" do
    assert_changes -> { identities(:kevin).access_tokens.count }, +1 do
      post my_access_tokens_path, params: { access_token: { description: "GitHub", permission: "read" } }
      travel_to 15.seconds.from_now
      follow_redirect!
      assert_equal "Token is no longer visible", flash[:alert]
    end
  end
end
