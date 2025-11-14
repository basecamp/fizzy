require "test_helper"

class Users::EmailAddresses::ConfirmationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:david)
    @new_email = "newemail@example.com"
    @token = @user.send(:generate_email_address_change_token, to: @new_email)
  end

  test "show" do
    get user_email_address_confirmation_path(user_id: @user.id, email_address_token: @token, script_name: @user.account.slug)
    assert_response :success
  end

  test "create" do
    old_email = @user.identity.email_address

    post user_email_address_confirmation_path(user_id: @user.id, email_address_token: @token, script_name: @user.account.slug)

    assert_equal @new_email, @user.reload.identity.email_address
    assert_redirected_to edit_user_url(script_name: @user.account.slug, id: @user)
  end

  test "create with invalid token" do
    assert_raises(ArgumentError) do
      post user_email_address_confirmation_path(user_id: @user.id, email_address_token: "invalid", script_name: @user.account.slug)
    end
  end
end
