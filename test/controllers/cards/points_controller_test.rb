require "test_helper"

class Cards::PointsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "edit" do
    get edit_card_points_path(cards(:logo))
    assert_response :success
  end

  test "update sets points" do
    patch card_points_path(cards(:logo)), params: { card: { points: 5 } }, as: :turbo_stream

    assert_response :success
    assert_equal 5, cards(:logo).reload.points
  end

  test "update clears points when blank" do
    cards(:logo).update!(points: 5)

    patch card_points_path(cards(:logo)), params: { card: { points: "" } }, as: :turbo_stream

    assert_response :success
    assert_nil cards(:logo).reload.points
  end

  test "update replaces points turbo frame" do
    patch card_points_path(cards(:logo)), params: { card: { points: 3 } }, as: :turbo_stream

    assert_response :success
    assert_includes response.body, dom_id(cards(:logo), :points)
  end
end
