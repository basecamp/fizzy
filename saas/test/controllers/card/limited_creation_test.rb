require "test_helper"

class Card::LimitedCreationTest < ActionDispatch::IntegrationTest
  test "cannot create cards via JSON when card limit exceeded" do
    sign_in_as :mike

    accounts(:initech).update_column(:cards_count, 1001)

    assert_no_difference -> { Card.count } do
      post board_cards_path(boards(:miltons_wish_list), script_name: accounts(:initech).slug, format: :json)
    end

    assert_response :forbidden
  end

  test "can create cards via HTML when card limit exceeded but they are drafts" do
    sign_in_as :mike

    accounts(:initech).update_column(:cards_count, 1001)
    boards(:miltons_wish_list).cards.drafted.where(creator: users(:mike)).destroy_all

    assert_difference -> { Card.count } do
      post board_cards_path(boards(:miltons_wish_list), script_name: accounts(:initech).slug)
    end

    assert_response :redirect
    assert Card.last.drafted?
  end

  test "cannot force published status via HTML when card limit exceeded" do
    sign_in_as :mike

    accounts(:initech).update_column(:cards_count, 1001)
    boards(:miltons_wish_list).cards.drafted.where(creator: users(:mike)).destroy_all

    assert_difference -> { Card.count } do
      post board_cards_path(boards(:miltons_wish_list), script_name: accounts(:initech).slug), params: { card: { status: "published" } }
    end

    assert_response :redirect
    assert Card.last.drafted?
  end

  test "cannot create cards via JSON when storage limit exceeded" do
    sign_in_as :mike

    Account.any_instance.stubs(:bytes_used).returns(1.1.gigabytes)

    assert_no_difference -> { Card.count } do
      post board_cards_path(boards(:miltons_wish_list), script_name: accounts(:initech).slug, format: :json)
    end

    assert_response :forbidden
  end
end
