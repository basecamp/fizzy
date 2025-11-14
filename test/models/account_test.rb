require "test_helper"

class AccountTest < ActiveSupport::TestCase
  test "create" do
    assert_difference "Account::JoinCode.count", +1 do
      Account.create!(name: "ACME corp")
    end
  end

  test "slug" do
    account = accounts("37s")
    assert_equal "/#{account.external_account_id}", account.slug
  end

  test ".create_with_admin_user creates a new local account" do
    Current.without_account do
      identity = identities(:david)
      account = nil

      assert_changes -> { Account.count }, +1 do
        assert_changes -> { User.count }, +2 do
          account = Account.create_with_admin_user(
            account: {
              external_account_id: ActiveRecord::FixtureSet.identify("account-create-with-admin-user-test"),
              name: "Account Create With Admin"
            },
            owner: {
              name: "David",
              identity: identity
            }
          )
        end
      end

      assert_not_nil account
      assert account.persisted?
      assert_equal ActiveRecord::FixtureSet.identify("account-create-with-admin-user-test"), account.external_account_id
      assert_equal "Account Create With Admin", account.name

      admin = account.users.find_by(role: "admin")
      assert_equal "David", admin.name
      assert_equal "david@37signals.com", admin.identity.email_address
      assert_equal "admin", admin.role
    end
  end
end
