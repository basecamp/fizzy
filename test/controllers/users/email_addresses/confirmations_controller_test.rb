require "test_helper"

class Users::EmailAddresses::ConfirmationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:david)
    @old_email = @user.identity.email_address
    @new_email = "newemail@example.com"
    @token = @user.send(:generate_email_address_change_token, to: @new_email)
  end

  test "show" do
    get user_email_address_confirmation_path(user_id: @user.id, email_address_token: @token, script_name: @user.account.slug)
    assert_response :success
  end

  test "create" do
    post user_email_address_confirmation_path(user_id: @user.id, email_address_token: @token, script_name: @user.account.slug)

    assert_equal @new_email, @user.reload.identity.email_address
    assert_redirected_to edit_user_url(script_name: @user.account.slug, id: @user)
  end

  test "create with invalid token" do
    post user_email_address_confirmation_path(user_id: @user.id, email_address_token: "invalid", script_name: @user.account.slug)

    assert_equal @user.identity.email_address, @old_email
    assert_response :unprocessable_entity
    assert_match /Link expired/, response.body
  end

  test "create as JSON" do
    post user_email_address_confirmation_path(user_id: @user.id, email_address_token: @token, script_name: @user.account.slug), as: :json

    assert_response :no_content
    assert_equal @new_email, @user.reload.identity.email_address
  end

  test "create as JSON with invalid token" do
    post user_email_address_confirmation_path(user_id: @user.id, email_address_token: "invalid", script_name: @user.account.slug), as: :json

    assert_response :unprocessable_entity
    assert_equal "Token is invalid or has expired", @response.parsed_body["error"]
    assert_equal @old_email, @user.reload.identity.email_address
  end

  test "create as JSON with expired token" do
    expired_token = @user.send(:generate_email_address_change_token, to: @new_email, expires_in: 0.seconds)

    travel_to 1.minute.from_now do
      post user_email_address_confirmation_path(user_id: @user.id, email_address_token: expired_token, script_name: @user.account.slug), as: :json

      assert_response :unprocessable_entity
      assert_equal "Token is invalid or has expired", @response.parsed_body["error"]
      assert_equal @old_email, @user.reload.identity.email_address
    end
  end

  test "create as JSON changes identity" do
    assert_equal @old_email, @user.identity.email_address

    post user_email_address_confirmation_path(user_id: @user.id, email_address_token: @token, script_name: @user.account.slug), as: :json

    assert_response :no_content
    @user.reload
    assert_equal @new_email, @user.identity.email_address
    assert_not_equal @old_email, @user.identity.email_address
  end
end
