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

  test "create is not found with single sign-on" do
    identity = identities(:kevin)
    old_token = identity.transfer_id

    sign_in_as identity
    current_session.update!(single_sign_on_authenticated_at: Time.current)

    with_single_sign_on do
      post transfer_token_path
    end

    assert_response :not_found
    assert_equal identity, Identity.find_by_transfer_id(old_token)
  end

  test "create requires authentication" do
    assert_no_difference -> { Identity::Transfer.count } do
      untenanted { post transfer_token_path }
    end
    assert_response :redirect
  end
end
