require "test_helper"

class TransferTokensControllerTest < ActionDispatch::IntegrationTest
  test "create regenerates the transfer token and revokes previously issued links" do
    identity = identities(:kevin)
    old_transfer_id = identity.transfer_id

    sign_in_as identity

    post transfer_token_path
    assert_response :redirect

    # Redeem the pre-regeneration link from a fresh, cookieless client (another device).
    reset!
    untenanted do
      put session_transfer_path(old_transfer_id)
      assert_response :bad_request, "The link issued before regeneration should no longer redeem"
    end
  end

  test "create requires authentication" do
    assert_no_difference -> { identities(:kevin).reload.transfer_token_generation } do
      untenanted { post transfer_token_path }
    end
    assert_response :redirect
  end
end
