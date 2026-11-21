require "test_helper"

class Boards::Columns::ClosedsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show" do
    get board_columns_closed_path(boards(:writebook))
    assert_response :success
  end

  test "show as JSON" do
    get board_columns_closed_path(boards(:writebook)), as: :json
    assert_response :success

    assert_kind_of Array, @response.parsed_body
  end

  test "show with a filter" do
    get board_columns_closed_path(boards(:writebook), tag_ids: [ tags(:web).id ]), as: :json
    assert_empty @response.parsed_body

    cards(:shipping).taggings.create!(tag: tags(:web))

    get board_columns_closed_path(boards(:writebook), tag_ids: [ tags(:web).id ]), as: :json
    assert_equal [ cards(:shipping).id ], @response.parsed_body.pluck("id")
  end
end
