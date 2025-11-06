require "test_helper"

class Boards::Columns::ClosedsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show" do
    get board_columns_closed_path(boards(:writebook))
    assert_response :success
  end
end
