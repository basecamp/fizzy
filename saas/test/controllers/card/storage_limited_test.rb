require "test_helper"

class Card::StorageLimitedTest < ActionDispatch::IntegrationTest
  test "draft card shows storage limit notice instead of create buttons when limit exceeded" do
    sign_in_as :mike

    Account.any_instance.stubs(:bytes_used).returns(1.gigabyte + 1)

    get card_draft_path(cards(:unfinished_thoughts), script_name: accounts(:initech).slug)

    assert_response :success
    assert_select ".card-perma__notch" do
      assert_select "strong", text: /used all/
      assert_select "a[href='https://github.com/basecamp/fizzy']", text: "Self-host Fizzy"
    end
    assert_select ".card-perma__notch-new-card-buttons", count: 0
  end

  test "draft card shows create buttons when under storage limit" do
    sign_in_as :mike

    get card_draft_path(cards(:unfinished_thoughts), script_name: accounts(:initech).slug)

    assert_response :success
    assert_select ".card-perma__notch-new-card-buttons"
  end
end
