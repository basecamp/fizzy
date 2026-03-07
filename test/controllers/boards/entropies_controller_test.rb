require "test_helper"

class Boards::EntropiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @board = boards(:writebook)
  end

  test "update" do
    assert_no_difference -> { Current.account.entropy.reload.auto_postpone_period } do
      put board_entropy_path(@board, format: :turbo_stream), params: { board: { auto_postpone_period: 123.days } }

      assert_equal 123.days, @board.entropy.reload.auto_postpone_period

      assert_turbo_stream action: :replace, target: dom_id(@board, :entropy)
    end
  end

  test "update requires board admin permission" do
    logout_and_sign_in_as :jz

    original_period = @board.entropy.auto_postpone_period

    put board_entropy_path(@board, format: :turbo_stream), params: { board: { auto_postpone_period: 1.day } }

    assert_response :forbidden
    assert_equal original_period, @board.entropy.reload.auto_postpone_period
  end

  test "update as JSON" do
    assert_no_difference -> { Current.account.entropy.reload.auto_postpone_period } do
      put board_entropy_path(@board), params: { board: { auto_postpone_period: 45.days } }, as: :json

      assert_response :success
      assert_equal 45.days, @board.entropy.reload.auto_postpone_period
      assert_equal 45.days, @response.parsed_body["auto_postpone_period"]
    end
  end

  test "update as JSON requires board admin permission" do
    logout_and_sign_in_as :jz

    original_period = @board.entropy.auto_postpone_period

    put board_entropy_path(@board), params: { board: { auto_postpone_period: 1.day } }, as: :json

    assert_response :forbidden
    assert_equal original_period, @board.entropy.reload.auto_postpone_period
  end
end
