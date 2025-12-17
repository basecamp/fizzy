require "test_helper"

class Users::VerificationsControllerTest < ActionDispatch::IntegrationTest
  test "new renders the auto-submit form" do
    sign_in_as :david

    get new_users_verification_path

    assert_response :ok
  end

  test "create verifies the user and redirects to join" do
    sign_in_as :david

    user = users(:david)
    user.update_column(:verified_at, nil)
    assert_not user.verified?

    post users_verifications_path

    assert_redirected_to new_users_join_path
    assert user.reload.verified?
  end
end
