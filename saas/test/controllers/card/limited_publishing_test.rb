require "test_helper"

class Card::LimitedPublishingTest < ActionDispatch::IntegrationTest
  test "cannot publish cards when card limit exceeded" do
    sign_in_as :mike

    accounts(:initech).update_column(:cards_count, 1001)

    post card_publish_path(cards(:unfinished_thoughts), script_name: accounts(:initech).slug)

    assert_response :forbidden
    assert cards(:unfinished_thoughts).reload.drafted?
  end

  test "cannot publish cards when storage limit exceeded" do
    sign_in_as :mike

    Account.any_instance.stubs(:bytes_used).returns(1.1.gigabytes)

    post card_publish_path(cards(:unfinished_thoughts), script_name: accounts(:initech).slug)

    assert_response :forbidden
    assert cards(:unfinished_thoughts).reload.drafted?
  end
end
