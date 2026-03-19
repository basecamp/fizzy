require "test_helper"

class Account::StorageLimitedTest < ActiveSupport::TestCase
  test "exceeding storage limit when bytes used exceeds 1 GB" do
    Account.any_instance.stubs(:bytes_used).returns(1.gigabyte + 1)

    assert accounts(:initech).exceeding_storage_limit?
  end

  test "not exceeding storage limit when bytes used equals 1 GB" do
    Account.any_instance.stubs(:bytes_used).returns(1.gigabyte)

    assert_not accounts(:initech).exceeding_storage_limit?
  end

  test "not exceeding storage limit when under 1 GB" do
    Account.any_instance.stubs(:bytes_used).returns(500.megabytes)

    assert_not accounts(:initech).exceeding_storage_limit?
  end

  test "nearing storage limit when within 500 MB of the limit" do
    Account.any_instance.stubs(:bytes_used).returns(600.megabytes)

    assert accounts(:initech).nearing_storage_limit?
  end

  test "not nearing storage limit when well under the threshold" do
    Account.any_instance.stubs(:bytes_used).returns(400.megabytes)

    assert_not accounts(:initech).nearing_storage_limit?
  end

  test "not nearing storage limit when already exceeding it" do
    Account.any_instance.stubs(:bytes_used).returns(1.gigabyte + 1)

    assert_not accounts(:initech).nearing_storage_limit?
  end
end
