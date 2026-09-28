require "test_helper"

class TransferTokensControllerTest < ActionDispatch::IntegrationTest
  test "create regenerates the transfer token and revokes previously issued links" do
    identity = identities(:kevin)
    old_token = identity.transfer_id

    sign_in_as identity

    post transfer_token_path
    assert_response :redirect

    reset!
    untenanted do
      put session_transfer_path(old_token)
      assert_response :bad_request, "The link issued before regeneration should no longer redeem"
    end
  end

  test "create requires authentication" do
    assert_no_difference -> { Identity::Transfer.count } do
      untenanted { post transfer_token_path }
    end
    assert_response :redirect
  end
end
