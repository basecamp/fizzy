require "test_helper"

class User::EmailAddressChangeableTest < ActiveSupport::TestCase
  test "send_email_address_change_confirmation" do
    user = users(:david)
    new_email_address = "new@example.com"

    assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob do
      user.send_email_address_change_confirmation(new_email_address)
    end

    assert_not_equal new_email_address, user.reload.email_address
  end

  test "generate_email_address_change_token" do
    user = users(:david)
    old_email = user.email_address
    new_email = "david.new@37signals.com"

    token = user.generate_email_address_change_token(to: new_email, expires_in: 30.minutes)

    assert_kind_of String, token
    assert token.present?
  end

  test "change_email_address_using_token" do
    user = users(:david)
    old_email = user.email_address
    new_email = "david.new@37signals.com"

    token = user.generate_email_address_change_token(to: new_email, expires_in: 30.minutes)

    assert_equal old_email, user.reload.email_address

    user.change_email_address_using_token(token)

    assert_equal new_email, user.reload.email_address
  end
end
