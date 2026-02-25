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

  test "failed with no reason" do
    import = Account::Import.create!(account: Current.account, identity: identities(:david), status: :failed)
    email = ImportMailer.failed(import)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ "david@37signals.com" ], email.to
    assert_equal "Your Fizzy account import failed", email.subject
    assert_match "corrupted export data", email.body.encoded
  end

  test "failed with conflict reason" do
    import = Account::Import.create!(account: Current.account, identity: identities(:david), status: :failed, failure_reason: :conflict)
    email = ImportMailer.failed(import)

    assert_emails 1 do
      email.deliver_now
    end

    assert_match "account you are trying to import already exists", email.body.encoded
  end

  test "failed with invalid_export reason" do
    import = Account::Import.create!(account: Current.account, identity: identities(:david), status: :failed, failure_reason: :invalid_export)
    email = ImportMailer.failed(import)

    assert_emails 1 do
      email.deliver_now
    end

    assert_match "isn't a Fizzy account export", email.body.encoded
  end
end
