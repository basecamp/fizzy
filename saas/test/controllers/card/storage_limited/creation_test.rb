require "test_helper"

class Card::StorageLimited::CreationTest < ActionDispatch::IntegrationTest
  test "cannot create cards via JSON when storage limit exceeded" do
    sign_in_as :mike

    Account.any_instance.stubs(:bytes_used).returns(1.gigabyte + 1)

    assert_no_difference -> { Card.count } do
      post board_cards_path(boards(:miltons_wish_list), script_name: accounts(:initech).slug),
        params: { card: { title: "Blocked card" } },
        as: :json
    end

    assert_response :forbidden
  end

  test "can create cards via HTML when storage limit exceeded since they become drafts" do
    sign_in_as :mike

    Account.any_instance.stubs(:bytes_used).returns(1.gigabyte + 1)
    accounts(:initech).update_column(:cards_count, 100)
    boards(:miltons_wish_list).cards.drafted.where(creator: users(:mike)).destroy_all

    assert_difference -> { Card.count } do
      post board_cards_path(boards(:miltons_wish_list), script_name: accounts(:initech).slug)
    end

    assert_response :redirect
    assert Card.last.drafted?
  end

  test "can create cards via JSON when under storage limit" do
    sign_in_as :mike

    Account.any_instance.stubs(:bytes_used).returns(500.megabytes)
    accounts(:initech).update_column(:cards_count, 100)

    assert_difference -> { Card.count } do
      post board_cards_path(boards(:miltons_wish_list), script_name: accounts(:initech).slug),
        params: { card: { title: "Allowed card" } },
        as: :json
    end

    assert_response :created
  end

  test "staff can create cards via JSON even when storage limit exceeded" do
    sign_in_as :mike

    Account.any_instance.stubs(:bytes_used).returns(1.gigabyte + 1)
    Identity.any_instance.stubs(:staff?).returns(true)
    accounts(:initech).update_column(:cards_count, 100)

    assert_difference -> { Card.count } do
      post board_cards_path(boards(:miltons_wish_list), script_name: accounts(:initech).slug),
        params: { card: { title: "Staff card" } },
        as: :json
    end

    assert_response :created
  end
end
