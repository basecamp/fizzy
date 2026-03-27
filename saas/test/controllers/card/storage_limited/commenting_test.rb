require "test_helper"

class Card::StorageLimited::CommentingTest < ActionDispatch::IntegrationTest
  test "cannot create comments when storage limit exceeded" do
    sign_in_as :david

    Account.any_instance.stubs(:bytes_used).returns(1.gigabyte + 1)
    Identity.any_instance.stubs(:staff?).returns(false)

    assert_no_difference -> { Comment.count } do
      post card_comments_path(cards(:logo), script_name: accounts(:"37s").slug),
        params: { comment: { body: "Blocked comment" } },
        as: :turbo_stream
    end

    assert_response :forbidden
  end

  test "can create comments when under storage limit" do
    sign_in_as :david

    assert_difference -> { Comment.count } do
      post card_comments_path(cards(:logo), script_name: accounts(:"37s").slug),
        params: { comment: { body: "Allowed comment" } },
        as: :turbo_stream
    end

    assert_response :success
  end

  test "staff can create comments even when storage limit exceeded" do
    sign_in_as :david

    Account.any_instance.stubs(:bytes_used).returns(1.gigabyte + 1)

    assert_difference -> { Comment.count } do
      post card_comments_path(cards(:logo), script_name: accounts(:"37s").slug),
        params: { comment: { body: "Staff comment" } },
        as: :turbo_stream
    end

    assert_response :success
  end
end
