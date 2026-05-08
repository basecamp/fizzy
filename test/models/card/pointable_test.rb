require "test_helper"

class Card::PointableTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "awards points to assignee on close" do
    card = cards(:logo)
    card.update!(points: 8)

    card.close(user: users(:david))

    assert_equal 8, card.closure.points_awarded
  end

  test "does not award points when card has no points" do
    card = cards(:logo)
    assert_nil card.points

    card.close(user: users(:david))

    assert_nil card.closure.points_awarded
  end

  test "does not award points when card has no assignee" do
    card = cards(:logo)
    card.assignments.delete_all
    card.update!(points: 5)

    card.close(user: users(:david))

    assert_nil card.closure.points_awarded
  end

  test "preserves points_awarded after card points are changed" do
    card = cards(:logo)
    card.update!(points: 8)
    card.close(user: users(:david))

    card.update!(points: 99)

    assert_equal 8, card.closure.reload.points_awarded
  end
end
