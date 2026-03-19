require "test_helper"

class Comment::StorageLimitedTest < ActionDispatch::IntegrationTest
  test "published card shows storage limit notice instead of comment form when limit exceeded" do
    sign_in_as :david

    Account.any_instance.stubs(:bytes_used).returns(1.gigabyte + 1)

    get card_path(cards(:logo), script_name: accounts(:"37s").slug)

    assert_response :success
    assert_select "strong", text: /used all/
    assert_select "a[href='https://github.com/basecamp/fizzy']", text: "Self-host Fizzy"
    assert_select "##{dom_id(cards(:logo), :new_comment)}", count: 0
  end

  test "published card shows comment form when under storage limit" do
    sign_in_as :david

    get card_path(cards(:logo), script_name: accounts(:"37s").slug)

    assert_response :success
    assert_select "##{dom_id(cards(:logo), :new_comment)}"
  end
end
