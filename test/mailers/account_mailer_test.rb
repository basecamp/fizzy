require "test_helper"

class AccountMailerTest < ActionMailer::TestCase
  setup do
    @account = accounts(:"37s")
    @user = users(:david)
    @account.cancel(initiated_by: @user)
    @cancellation = @account.cancellation
  end

  test "cancellation sends to initiating user" do
    email = AccountMailer.cancellation(@cancellation)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ @user.identity.email_address ], email.to
  end

  test "cancellation includes account name" do
    email = AccountMailer.cancellation(@cancellation)

    assert_match @account.name, email.body.encoded
  end

  test "cancellation includes support email" do
    email = AccountMailer.cancellation(@cancellation)

    assert_match "support@fizzy.do", email.body.encoded
  end

  test "cancellation has correct subject" do
    email = AccountMailer.cancellation(@cancellation)

    assert_equal "Your Fizzy account was cancelled", email.subject
  end

  test "cancellation has both HTML and text parts" do
    email = AccountMailer.cancellation(@cancellation)

    assert email.html_part.present?, "Email should have HTML part"
    assert email.text_part.present?, "Email should have text part"
  end

  test "cancellation mentions account access is removed" do
    email = AccountMailer.cancellation(@cancellation)

    assert_match /no one can access/i, email.body.encoded
  end

  test "cancellation mentions data will be deleted" do
    email = AccountMailer.cancellation(@cancellation)

    assert_match /deleted/i, email.body.encoded
  end
end
