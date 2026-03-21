require "test_helper"

class Card::StorageLimited::PublishingTest < ActionDispatch::IntegrationTest
  test "cannot publish cards when storage limit exceeded" do
    sign_in_as :mike

    Account.any_instance.stubs(:bytes_used).returns(1.gigabyte + 1)

    post card_publish_path(cards(:unfinished_thoughts), script_name: accounts(:initech).slug)

    assert_response :forbidden
    assert cards(:unfinished_thoughts).reload.drafted?
  end

  test "can publish cards when under storage limit" do
    sign_in_as :mike

    post card_publish_path(cards(:unfinished_thoughts), script_name: accounts(:initech).slug)

    assert_response :redirect
    assert cards(:unfinished_thoughts).reload.published?
  end

  test "staff can publish cards even when storage limit exceeded" do
    sign_in_as :mike

    Account.any_instance.stubs(:bytes_used).returns(1.gigabyte + 1)
    Identity.any_instance.stubs(:staff?).returns(true)

    post card_publish_path(cards(:unfinished_thoughts), script_name: accounts(:initech).slug)

    assert_response :redirect
    assert cards(:unfinished_thoughts).reload.published?
  end
end
