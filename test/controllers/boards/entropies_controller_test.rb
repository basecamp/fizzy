require "test_helper"

class Boards::EntropiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @board = boards(:writebook)
  end

  test "update" do
    put board_entropy_path(@board, format: :turbo_stream), params: { board: { auto_postpone_period: 1.day } }

    assert_equal 1.day, @board.entropy.reload.auto_postpone_period

    assert_turbo_stream action: :replace, target: dom_id(@board, :entropy)
  end
end
