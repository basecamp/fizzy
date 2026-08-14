require "test_helper"

class HotcellzControllerTest < ActionDispatch::IntegrationTest
  # The literal path a monitor polls, asserted as the string it will be configured with.
  HOTCELLZ = "/hotcellz"

  # Unauthenticated so a monitor can poll it, and outside the account scope like the /up beside it.
  test "answers without a session" do
    get HOTCELLZ

    assert_equal "application/json", response.media_type
    assert_equal %w[ at host root groups describe metrics echo ], response.parsed_body.keys
  end

  # A poll lands on one of the web hosts and the answer is about that host's cell, so an answer that does
  # not say which one cannot be acted on.
  test "names the host that answered" do
    get HOTCELLZ

    assert_equal Socket.gethostname, response.parsed_body["host"]
  end

  # Spelled the way the cell spells `at` in its own log lines, so a reading lines up against them.
  test "stamps the reading with subsecond resolution" do
    get HOTCELLZ

    assert_match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z\z/, response.parsed_body["at"])
  end

  # The status is what gets alerted on, so it has to move without anyone parsing the body.
  test "answers 503 when a check fails" do
    get HOTCELLZ

    assert_response :service_unavailable
  end

  # The endpoint is the last step of booting an accessory, which is the moment a cell is least likely to
  # answer. One that raises there is one nobody can use to find out why.
  test "reports an unconfigured cell rather than raising" do
    get HOTCELLZ

    assert_equal [ false, false, false ], checks.map { it["ok"] }
    assert_match "HOTCELL_ROOT is unset", response.parsed_body["echo"]["error"]
  end

  test "reports a cell that will not answer rather than raising" do
    HotCell.cell(Fizzy::Saas::Cell::NAME).stubs(:directory).returns("tmp/no-cell-here")

    get HOTCELLZ

    assert_equal [ false, false, false ], checks.map { it["ok"] }
    assert_match "Errno::ENOENT", response.parsed_body["echo"]["error"]
  end

  private
    def checks
      response.parsed_body.values_at("describe", "metrics", "echo")
    end
end
