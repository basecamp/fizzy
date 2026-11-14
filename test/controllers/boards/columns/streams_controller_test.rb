require "test_helper"

class Boards::Columns::StreamsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show" do
    get board_columns_stream_path(boards(:writebook))
    assert_response :success
  end

  test "show as JSON" do
    get board_columns_stream_path(boards(:writebook)), as: :json
    assert_response :success

    assert_kind_of Array, @response.parsed_body
    assert response.headers["X-Total-Count"].present?, "Expected X-Total-Count header"
  end

  test "show with a filter" do
    get board_columns_stream_path(boards(:writebook), tag_ids: [ tags(:web).id ]), as: :json
    assert_empty @response.parsed_body

    get board_columns_stream_path(boards(:writebook), creator_ids: [ cards(:buy_domain).creator.id ]), as: :json
    assert_includes @response.parsed_body.pluck("id"), cards(:buy_domain).id
  end
end
