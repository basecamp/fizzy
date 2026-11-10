require "test_helper"

class Public::BoardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin

    boards(:writebook).publish
  end

  test "show" do
    get published_board_path(boards(:writebook))
    assert_response :success
  end

  test "not found if the board is not published" do
    key = boards(:writebook).publication.key

    boards(:writebook).unpublish
    get public_board_path(key)

    assert_response :not_found
  end

  test "show excludes draft cards from closed count" do
    draft_card = cards(:buy_domain)
    draft_card.update!(status: :drafted)
    Current.set(user: users(:david)) { draft_card.close }

    get published_board_path(boards(:writebook))
    assert_response :success
    assert_select ".cards--closed .cards__expander-count", "1"
  end

  test "show works without authentication" do
    sign_out
    get published_board_path(boards(:writebook))
    assert_response :success
  end

  test "extensionless public pages always render full HTML" do
    sign_out

    get published_board_path(boards(:writebook)), headers: { "Accept" => nil, "X-Requested-With" => "XMLHttpRequest" }
    assert_response :success
    assert_equal "text/html", response.media_type
    assert_select "body.public"

    get published_board_path(boards(:writebook)), headers: { "Accept" => "application/json" }
    assert_response :success
    assert_equal "text/html", response.media_type
    assert_select "body.public"
  end
end
