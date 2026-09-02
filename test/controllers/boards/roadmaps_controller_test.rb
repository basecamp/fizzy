require "test_helper"

class Boards::RoadmapsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "a member of the board opens its roadmap and sees it" do
    board = boards(:writebook)

    # Current.session must be set because publishing tracks an event whose creator defaults to Current.user.
    card = Current.set(session: sessions(:kevin)) do
      board.cards.create!(title: "Ship the redesign", creator: users(:kevin), status: "published").tap do |card|
        card.toggle_tag_with "phase:p1"
      end
    end

    get board_roadmap_path(board)

    assert_response :success
    assert_select "h2", text: "P1"
    assert_select "li", text: /#{card.number}.*Ship the redesign/
  end

  test "a user without access cannot reach another board's roadmap" do
    logout_and_sign_in_as :david
    board = boards(:private)

    get board_roadmap_path(board)

    assert_response :not_found
  end
end
