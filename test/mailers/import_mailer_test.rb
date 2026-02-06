require "test_helper"

class ImportMailerTest < ActionMailer::TestCase
  test "completed" do
    email = ImportMailer.completed(identities(:david), accounts(:"37s"))

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ "david@37signals.com" ], email.to
    assert_equal "Your Fizzy account import is done", email.subject
    assert_match accounts(:"37s").slug, email.body.encoded
  end
end
