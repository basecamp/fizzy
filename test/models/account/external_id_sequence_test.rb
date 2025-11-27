require "test_helper"

class Account::ExternalIdSequenceTest < ActiveSupport::TestCase
  setup do
    Account::ExternalIdSequence.delete_all
  end

  test "generate sequential values" do
    first_value = Account::ExternalIdSequence.next
    second_value = Account::ExternalIdSequence.next
    third_value = Account::ExternalIdSequence.next

    assert_equal first_value + 1, second_value
    assert_equal second_value + 1, third_value
  end

  test "start from the maximum existing external account id" do
    max_id = Account.maximum(:external_account_id) || 0

    first_value = Account::ExternalIdSequence.next

    assert_equal max_id + 1, first_value
  end

  test "use a single record for the sequence" do
    3.times { Account::ExternalIdSequence.next }

    assert_equal 1, Account::ExternalIdSequence.count
  end

  test "handle concurrent access safely" do
    values = 20.times.map do
      Thread.new do
        Account::ExternalIdSequence.next
      end
    end.map(&:value)

    assert_equal 20, values.uniq.size, "All values should be unique"
    assert_equal values.min..values.max, values.sort.first..values.sort.last
    assert_equal 20, values.max - values.min + 1, "Values should be sequential with no gaps"
  end
end
