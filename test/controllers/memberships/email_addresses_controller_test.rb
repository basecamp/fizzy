require "test_helper"

class Memberships::EmailAddressesControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    untenanted do
      sign_in_as :kevin

      membership = memberships(:kevin_in_37signals)

      get new_email_address_path(membership_id: membership.id)
      assert_response :success
    end
  end

  test "create" do
    untenanted do
      sign_in_as :kevin

      membership = memberships(:kevin_in_37signals)

      assert_enqueued_emails 1 do
        post email_addresses_path(membership_id: membership.id),
             params: { email_address: "newemail@example.com" }
      end

      assert_response :success
    end
  end

  test "create with an email for someone already in the account" do
    untenanted do
      sign_in_as :kevin

      membership = memberships(:kevin_in_37signals)

      post email_addresses_path(membership_id: membership.id),
           params: { email_address: identities(:david).email_address }

      assert_redirected_to new_email_address_path
      assert_equal "You already have a user in this account with that email address", flash[:alert]
    end
  end
end
