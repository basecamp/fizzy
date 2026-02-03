require "test_helper"

class Prompts::Boards::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @board = boards(:writebook)
  end

  test "index" do
    get prompts_board_users_path(@board)
    assert_response :success
    assert_select "lexxy-prompt-item", count: 3
  end

  test "index excludes inactive users" do
    get prompts_board_users_path(@board)
    assert_response :success
    assert_select "lexxy-prompt-item[search*='David']", count: 1

    users(:david).update!(active: false)

    get prompts_board_users_path(@board)
    assert_response :success
    assert_select "lexxy-prompt-item[search*='David']", count: 0
  end
end
