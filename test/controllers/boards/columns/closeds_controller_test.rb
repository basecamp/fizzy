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
end
