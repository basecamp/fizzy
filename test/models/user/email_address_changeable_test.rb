require "test_helper"

class User::EmailAddressChangeableTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @identity = identities(:kevin)
    @user = @identity.users.find_by!(account: accounts("37s"))
    @new_email = "newart@example.com"
    @old_email = @identity.email_address
  end

  test "send_email_address_change_confirmation" do
    assert_emails 1 do
      @user.send_email_address_change_confirmation(@new_email)
    end
  end

  test "change_email_address" do
    old_identity = @identity
    new_identity = identities(:mike)

    assert_difference -> { Identity.count }, +1 do
      @user.change_email_address(@new_email)
    end

    assert_equal @new_email, @user.reload.identity.email_address
    assert_not old_identity.reload.users.exists?(id: @user.id)
    assert_equal @new_email, @user.reload.identity.email_address

    assert_no_difference -> { Identity.count } do
      @user.change_email_address(new_identity.email_address)
    end
    assert_equal new_identity.email_address, @user.reload.identity.email_address
  end

  test "change_email_address_using_token" do
    token = @user.send(:generate_email_address_change_token, to: @new_email)

    @user.change_email_address_using_token(token)

    assert_equal @new_email, @user.reload.identity.email_address
  end

  test "change_email_address_using_token with invalid token" do
    assert_not @user.change_email_address_using_token("invalid_token")
    assert_equal @old_email, @user.reload.identity.email_address

    token = @user.send(:generate_email_address_change_token, to: @new_email)
    old_email = "#{SecureRandom.hex(16)}@example.com"
    @identity.update!(email_address: old_email)
    @user.reload

    assert_not @user.change_email_address_using_token(token)
    assert_equal old_email, @user.reload.identity.email_address
  end
end
