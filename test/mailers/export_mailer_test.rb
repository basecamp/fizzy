require "test_helper"

class ExportMailerTest < ActionMailer::TestCase
  test "completed for account export" do
    export = Account::Export.create!(account: Current.account, user: users(:david))
    email = ExportMailer.completed(export)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ "david@37signals.com" ], email.to
    assert_equal "Your Fizzy data export is ready for download", email.subject
    assert_match %r{/exports/#{export.id}}, email.body.encoded
  end

  test "completed for user data export" do
    export = User::DataExport.create!(account: Current.account, user: users(:david))
    email = ExportMailer.completed(export)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ "david@37signals.com" ], email.to
    assert_equal "Your Fizzy data export is ready for download", email.subject
    assert_match %r{/users/#{export.user.id}/data_exports/#{export.id}}, email.body.encoded
  end
end
