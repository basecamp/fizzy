require "test_helper"

class Account::LimitedTest < ActiveSupport::TestCase
  test "detect nearing card limit" do
    # Paid plans are never limited
    accounts(:"37s").update_column(:cards_count, 1_000_000)
    assert_not accounts(:"37s").nearing_plan_cards_limit?

    # Free plan not near limit
    accounts(:initech).update_column(:cards_count, 899)
    assert_not accounts(:initech).nearing_plan_cards_limit?

    # Free plan near limit
    accounts(:initech).update_column(:cards_count, 900)
    assert_not accounts(:initech).nearing_plan_cards_limit?

    accounts(:initech).update_column(:cards_count, 901)
    assert accounts(:initech).nearing_plan_cards_limit?
  end

  test "detect exceeding card limit" do
    # Paid plans are never limited
    accounts(:"37s").update_column(:cards_count, 1_000_000)
    assert_not accounts(:"37s").exceeding_card_limit?

    # Free plan under limit
    accounts(:initech).update_column(:cards_count, 999)
    assert_not accounts(:initech).exceeding_card_limit?

    # Free plan over limit
    accounts(:initech).update_column(:cards_count, 1001)
    assert accounts(:initech).exceeding_card_limit?
  end

  test "override limits" do
    account = accounts(:initech)
    account.update_column(:cards_count, 1001)

    assert account.exceeding_card_limit?
    assert_equal 1001, account.billed_cards_count

    account.override_limits card_count: 500
    assert_not account.exceeding_card_limit?
    assert_equal 500, account.billed_cards_count
    assert_equal 1001, account.cards_count # original unchanged

    account.reset_overridden_limits
    assert account.exceeding_card_limit?
    assert_equal 1001, account.billed_cards_count
  end

  test "comped accounts are never limited" do
    account = accounts(:initech)
    account.update_column(:cards_count, 1_000_000)

    assert account.exceeding_card_limit?
    assert account.nearing_plan_cards_limit?

    account.comp

    assert_not account.exceeding_card_limit?
    assert_not account.nearing_plan_cards_limit?
  end

  test "uncomping an account restores limits" do
    account = accounts(:initech)
    account.update_column(:cards_count, 1_000_000)
    account.comp

    assert_not account.exceeding_card_limit?

    account.uncomp

    assert account.exceeding_card_limit?
  end

  test "detect nearing storage limit" do
    # Paid plans have large storage limits
    accounts(:"37s").stubs(:bytes_used).returns(4.gigabytes)
    assert_not accounts(:"37s").nearing_plan_storage_limit?

    # Free plan not near limit
    accounts(:initech).stubs(:bytes_used).returns(400.megabytes)
    assert_not accounts(:initech).nearing_plan_storage_limit?

    # Free plan near limit
    accounts(:initech).stubs(:bytes_used).returns(600.megabytes)
    assert accounts(:initech).nearing_plan_storage_limit?
  end

  test "detect exceeding storage limit" do
    # Free plan under limit
    accounts(:initech).stubs(:bytes_used).returns(900.megabytes)
    assert_not accounts(:initech).exceeding_storage_limit?

    # Free plan over limit
    accounts(:initech).stubs(:bytes_used).returns(1.1.gigabytes)
    assert accounts(:initech).exceeding_storage_limit?
  end

  test "override bytes_used limits" do
    account = accounts(:initech)
    account.stubs(:bytes_used).returns(1.1.gigabytes)

    assert account.exceeding_storage_limit?
    assert_equal 1.1.gigabytes, account.billed_bytes_used

    account.override_limits bytes_used: 500.megabytes
    assert_not account.exceeding_storage_limit?
    assert_equal 500.megabytes, account.billed_bytes_used
    assert_equal 1.1.gigabytes, account.bytes_used # original unchanged

    account.reset_overridden_limits
    assert account.exceeding_storage_limit?
    assert_equal 1.1.gigabytes, account.billed_bytes_used
  end
end
