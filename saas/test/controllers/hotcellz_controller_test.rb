require "test_helper"

class HotcellzControllerTest < ActionDispatch::IntegrationTest
  test "staff can see whether the cell is reachable" do
    sign_in_as :david

    untenanted { get saas.hotcellz_path }

    assert_response :success
  end

  test "non-staff cannot" do
    sign_in_as :jz

    untenanted { get saas.hotcellz_path }

    assert_response :forbidden
  end

  # The page is the last step of booting an accessory, which is the moment a cell is least likely to
  # answer. One that raises there is one nobody can use to find out why.
  test "reports an unconfigured cell rather than raising" do
    sign_in_as :david

    untenanted { get saas.hotcellz_path }

    assert_response :success
    assert_select "pre", text: /HOTCELL_ROOT is unset/
  end

  test "reports a cell that will not answer rather than raising" do
    sign_in_as :david
    HotCell.cell(Fizzy::Saas::Cell::NAME).stubs(:directory).returns("tmp/no-cell-here")

    untenanted { get saas.hotcellz_path }

    assert_response :success
    assert_select "pre", text: /Errno::ENOENT/
  end
end
