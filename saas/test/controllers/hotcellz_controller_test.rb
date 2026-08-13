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

  test "answers JSON with no layout, so a rollout can read it from a terminal" do
    sign_in_as :david

    untenanted { get saas.hotcellz_path }

    assert_equal "application/json", response.media_type
    assert_equal %w[ at root groups describe metrics echo ], response.parsed_body.keys
  end

  # Spelled the way the cell spells `at` in its own log lines, so a reading lines up against them.
  test "stamps the reading with subsecond resolution" do
    sign_in_as :david

    untenanted { get saas.hotcellz_path }

    assert_match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z\z/, response.parsed_body["at"])
  end

  # The endpoint is the last step of booting an accessory, which is the moment a cell is least likely to
  # answer. One that raises there is one nobody can use to find out why.
  test "reports an unconfigured cell rather than raising" do
    sign_in_as :david

    untenanted { get saas.hotcellz_path }

    assert_response :success
    assert_equal [ false, false, false ], checks.map { it["ok"] }
    assert_match "HOTCELL_ROOT is unset", response.parsed_body["echo"]["error"]
  end

  test "reports a cell that will not answer rather than raising" do
    sign_in_as :david
    HotCell.cell(Fizzy::Saas::Cell::NAME).stubs(:directory).returns("tmp/no-cell-here")

    untenanted { get saas.hotcellz_path }

    assert_response :success
    assert_equal [ false, false, false ], checks.map { it["ok"] }
    assert_match "Errno::ENOENT", response.parsed_body["echo"]["error"]
  end

  private
    def checks
      response.parsed_body.values_at("describe", "metrics", "echo")
    end
end
