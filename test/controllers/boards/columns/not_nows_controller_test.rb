require "test_helper"

class Boards::Columns::NotNowsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show" do
    get board_columns_not_now_path(boards(:writebook))
    assert_response :success
  end

  test "show as JSON" do
    get board_columns_not_now_path(boards(:writebook)), as: :json
    assert_response :success

    assert_kind_of Array, @response.parsed_body
  end

  test "show with a filter" do
    cards(:layout).postpone(user: users(:kevin))

    get board_columns_not_now_path(boards(:writebook), tag_ids: [ tags(:mobile).id ]), as: :json
    assert_equal [ cards(:layout).id ], @response.parsed_body.pluck("id")

    get board_columns_not_now_path(boards(:writebook), tag_ids: [ tags(:web).id ], creator_ids: [ users(:kevin).id ]), as: :json
    assert_empty @response.parsed_body
  end
end
