require "test_helper"

class Users::EmailAddressesControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    sign_in_as :david
    @user = users(:david)
  end

  test "new" do
    untenanted do
      get new_user_email_address_path(@user)
      assert_response :success
    end
  end

  test "create" do
    untenanted do
      assert_emails 1 do
        post user_email_addresses_path(@user), params: { email_address: "newemail@example.com" }
      end
      assert_response :success
    end
  end

  test "create with existing email in same account" do
    existing_user = users(:kevin)
    existing_email = existing_user.identity.email_address

    untenanted do
      post user_email_addresses_path(@user), params: { email_address: existing_email }
      assert_redirected_to new_user_email_address_path(@user)
      assert_equal "You already have a user in this account with that email address", flash[:alert]
    end
  end

  test "create for other user" do
    other_user = users(:kevin)

    untenanted do
      assert_no_emails do
        post user_email_addresses_path(other_user), params: { email_address: "newemail@example.com" }
      end
      assert_response :not_found
    end
  end
end
