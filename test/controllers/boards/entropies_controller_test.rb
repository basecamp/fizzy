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

  test "update requires board admin permission" do
    logout_and_sign_in_as :jz

    original_period = @board.entropy.auto_postpone_period

    put board_entropy_path(@board, format: :turbo_stream), params: { board: { auto_postpone_period: 1.day } }

    assert_response :forbidden
    assert_equal original_period, @board.entropy.reload.auto_postpone_period
  end
end
