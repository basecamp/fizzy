require "test_helper"

class Account::StorageExceptionTest < ActiveSupport::TestCase
  test "storage limit returns default when no exception exists" do
    assert_equal Account::StorageLimited::DEFAULT_STORAGE_LIMIT, accounts(:initech).storage_limit
  end

  test "storage limit returns exception value when one exists" do
    account = accounts(:initech)
    account.add_storage_exception(5.gigabytes)

    assert_equal 5.gigabytes, account.storage_limit
  end

  test "add storage exception creates a new record" do
    account = accounts(:initech)

    assert_difference -> { Account::StorageException.count } do
      account.add_storage_exception(2.gigabytes)
    end

    assert_equal 2.gigabytes, account.storage_exception.bytes_allowed
  end

  test "add storage exception updates existing record" do
    account = accounts(:initech)
    account.add_storage_exception(2.gigabytes)

    assert_no_difference -> { Account::StorageException.count } do
      account.add_storage_exception(10.gigabytes)
    end

    assert_equal 10.gigabytes, account.storage_exception.reload.bytes_allowed
  end

  test "exceeding storage limit respects exception" do
    account = accounts(:initech)
    Account.any_instance.stubs(:bytes_used).returns(2.gigabytes)

    assert account.exceeding_storage_limit?

    account.add_storage_exception(5.gigabytes)

    assert_not account.exceeding_storage_limit?
  end
end
