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

      assert_predicate account.system_user, :present?
    end
  end

  test "#system_user returns the system user of the account" do
    system_user = User.find_by!(account: accounts("37s"), role: :system)

    assert_equal system_user, accounts("37s").system_user
  end

  test "#system_user raises if there is no system user" do
    account = Account.create!(name: "No System User Account")

    assert_raises ActiveRecord::RecordNotFound do
      account.system_user
    end
  end

  test "external_account_id auto-increments on creation" do
    account1 = Account.create!(name: "First Account")
    account2 = Account.create!(name: "Second Account")

    assert_not_nil account1.external_account_id
    assert_not_nil account2.external_account_id
    assert_equal account1.external_account_id + 1, account2.external_account_id
  end

  test "external_account_id can be overridden without creating sequence entry" do
    custom_id = Account.last.id + 99999

    assert_no_difference -> { ExternalAccount.count } do
      account = Account.create!(name: "Custom ID Account", external_account_id: custom_id)
      assert_equal custom_id, account.external_account_id
    end
  end
end
