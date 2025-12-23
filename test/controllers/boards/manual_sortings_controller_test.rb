require "test_helper"

class Boards::ManualSortingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @board = boards(:writebook)
  end

  test "enable manual sorting" do
    assert_not @board.manual_sorting_enabled?

    assert_changes -> { @board.reload.manual_sorting_enabled? }, from: false, to: true do
      post board_manual_sorting_path(@board, format: :turbo_stream)
    end

    assert_turbo_stream action: :replace, target: dom_id(@board, :manual_sorting)
  end

  test "disable manual sorting" do
    @board.update!(manual_sorting_enabled: true)
    assert @board.manual_sorting_enabled?

    assert_changes -> { @board.reload.manual_sorting_enabled? }, from: true, to: false do
      delete board_manual_sorting_path(@board, format: :turbo_stream)
    end

    assert_turbo_stream action: :replace, target: dom_id(@board, :manual_sorting)
  end

  test "enable requires board admin permission" do
    logout_and_sign_in_as :jz

    assert_not @board.manual_sorting_enabled?

    post board_manual_sorting_path(@board, format: :turbo_stream)

    assert_response :forbidden
    assert_not @board.reload.manual_sorting_enabled?
  end

  test "disable requires board admin permission" do
    logout_and_sign_in_as :jz

    @board.update!(manual_sorting_enabled: true)
    assert @board.manual_sorting_enabled?

    delete board_manual_sorting_path(@board, format: :turbo_stream)

    assert_response :forbidden
    assert @board.reload.manual_sorting_enabled?
  end
end

