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

  test ".create_with_owner creates a new local account" do
    Current.without_account do
      identity = identities(:david)
      account = nil

      assert_changes -> { Account.count }, +1 do
        assert_changes -> { User.count }, +2 do
          account = Account.create_with_owner(
            account: {
              external_account_id: ActiveRecord::FixtureSet.identify("account-create-with-owner-test"),
              name: "Account Create With Owner"
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
      assert_equal ActiveRecord::FixtureSet.identify("account-create-with-owner-test"), account.external_account_id
      assert_equal "Account Create With Owner", account.name

      owner = account.users.find_by(role: "owner")
      assert_equal "David", owner.name
      assert_equal "david@37signals.com", owner.identity.email_address
      assert_equal "owner", owner.role
      assert owner.admin?, "owner should also be considered an admin"

      assert_predicate account.system_user, :present?

      assert owner.verified?, "owner should be verified on account creation"
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

  test "external_account_id can be overridden" do
    custom_id = 999999
    sequence_value_before = Account::ExternalIdSequence.first_or_create!(value: 0).value

    account = Account.create!(name: "Custom ID Account", external_account_id: custom_id)

    assert_equal custom_id, account.external_account_id
    assert_equal sequence_value_before, Account::ExternalIdSequence.value
  end
end
