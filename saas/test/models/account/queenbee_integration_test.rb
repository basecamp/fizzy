require "test_helper"
require "queenbee/testing/client"

class Account::QueenbeeIntegrationTest < ActiveSupport::TestCase
  include Queenbee::Testing::Client

  # Fizzy creates accounts via its own Signup flow (Fizzy → Queenbee),
  # not via Queenbee pushing to Fizzy, so create_with_dependents is N/A.
  undef_method :test_client_class_should_respond_to_create_with_dependents

  setup do
    @account = accounts(:"37s")
  end

  test "find_by_queenbee_id looks up by external_account_id" do
    assert_equal @account, Account.find_by_queenbee_id(@account.external_account_id)
  end

  test "queenbee_id returns external_account_id" do
    assert_equal @account.external_account_id, @account.queenbee_id
  end

  test "cancel! creates cancellation attributed to system user" do
    @account.cancel!

    assert @account.cancelled?
    assert_equal @account.system_user, @account.cancellation.initiated_by
  end

  test "cancel! is idempotent" do
    @account.cancel!
    assert_no_difference -> { Account::Cancellation.count } do
      @account.cancel!
    end
  end

  test "cancel and reactivate round-trips" do
    @account.cancel!
    assert_not @account.active?

    @account.reactivate!
    @account.reload
    assert @account.active?
  end

  test "deactivate! cancels the account" do
    @account.deactivate!
    assert @account.cancelled?
  end

  test "owner_name and owner_email from account owner" do
    assert_equal users(:jason).name, @account.owner_name
    assert_equal "jason@37signals.com", @account.owner_email
  end

  test "comped= is a no-op" do
    @account.comped = true
    assert_not @account.comped?
  end

  test "transferred_ownership! raises NotImplementedError" do
    assert_raises(NotImplementedError) { @account.transferred_ownership! }
  end

  test "qb_serializable_hash includes queenbee_id and subscription" do
    hash = @account.qb_serializable_hash
    assert_equal @account.external_account_id, hash[:id]
    assert_equal({ quantity: 1 }, hash[:subscription])
  end
end
