require "test_helper"

class AccountTest < ActiveSupport::TestCase
  test "slug" do
    account = Account.sole
    assert_equal "/#{ApplicationRecord.current_tenant}", account.slug
  end

  test ".create_with_admin_user creates a new local account" do
    ApplicationRecord.create_tenant("account-create-with-dependents") do
      account = Account.create_with_admin_user(
        account: {
          external_account_id: ActiveRecord::FixtureSet.identify("account-create-with-admin-user-test"),
          name: "Account Create With Admin"
        },
        owner: {
          name: "David",
          email_address: "david@37signals.com"
        }
      )
      assert_not_nil account
      assert account.persisted?
      assert_equal 1, Account.count
      assert_equal ActiveRecord::FixtureSet.identify("account-create-with-admin-user-test"), account.external_account_id
      assert_equal "Account Create With Admin", account.name

      assert_equal 2, User.count

      system = User.find_by(role: "system")
      assert system

      admin = User.find_by(role: "admin")
      assert_equal "David", admin.name
      assert_equal "david@37signals.com", admin.email_address
      assert_equal "admin", admin.role
    end
  end
end
