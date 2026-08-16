require "test_helper"

class HotcellzControllerTest < ActionDispatch::IntegrationTest
  # The literal paths a monitor and a person are configured with, asserted as the strings they will hold.
  HOTCELLZ = "/hotcellz"
  HOTCELLZ_TEST = "/hotcellz/test"

  # Unauthenticated so a monitor can poll it, and outside the account scope like the /up beside it.
  test "answers without a session" do
    get HOTCELLZ

    assert_response :service_unavailable
    assert_equal "text/plain", response.media_type
    assert_equal "FAIL", response.body
  end

  # A monitor reads the status and a person reads the word. Neither should have to parse anything, and
  # nothing about the cell's inventory, counters or configuration belongs in front of a stranger.
  test "tells an unauthenticated caller nothing but whether the cell answered" do
    get HOTCELLZ

    assert_no_match(/hotcell|running|queued|uptime|HOTCELL_ROOT/i, response.body)
  end

  # describe and metrics ask the supervisor inline, with no fork and no queue. So an unauthenticated flood
  # cannot make the cell do work, which is the whole reason the round trips moved to their own action.
  test "runs no work-socket round trip" do
    Fizzy::Saas::Cell.stubs(:echo).raises("echo must not run here")
    Fizzy::Saas::Cell.stubs(:reopen).raises("reopen must not run here")

    get HOTCELLZ

    assert_response :service_unavailable
  end

  test "refuses the test action without a session" do
    get HOTCELLZ_TEST

    assert_response :forbidden
  end

  # Signups are open, so an authenticated identity is close to anyone. The round trips fork a worker, and
  # the staff gate is the only thing bounding who may spend one.
  test "refuses the test action to a signed-in identity that is not staff" do
    sign_in_as :mike

    untenanted { get HOTCELLZ_TEST }

    assert_response :forbidden
  end

  test "reports every check to staff" do
    sign_in_as :david

    untenanted { get HOTCELLZ_TEST }

    assert_equal "application/json", response.media_type
    assert_equal %w[ at host root groups describe metrics echo reopen ], response.parsed_body.keys
  end

  # Spelled the way the cell spells `at` in its own log lines, so a reading lines up against them.
  test "stamps the reading with subsecond resolution" do
    sign_in_as :david

    untenanted { get HOTCELLZ_TEST }

    assert_match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z\z/, response.parsed_body["at"])
  end

  # A poll lands on one of the web hosts and the answer is about that host's cell, so an answer that does
  # not say which one cannot be acted on.
  test "names the host that answered" do
    sign_in_as :david

    untenanted { get HOTCELLZ_TEST }

    assert_equal Socket.gethostname, response.parsed_body["host"]
  end

  # The endpoint is the last step of booting an accessory, which is the moment a cell is least likely to
  # answer. One that raises there is one nobody can use to find out why.
  test "reports an unconfigured cell rather than raising" do
    sign_in_as :david

    untenanted { get HOTCELLZ_TEST }

    assert_response :service_unavailable
    assert_equal [ false, false, false, false ], checks.map { it["ok"] }
    assert_match "HOTCELL_ROOT is unset", response.parsed_body["echo"]["error"]
  end

  test "reports a cell that will not answer rather than raising" do
    HotCell.cell(Fizzy::Saas::Cell::NAME).stubs(:directory).returns("tmp/no-cell-here")
    sign_in_as :david

    untenanted { get HOTCELLZ_TEST }

    assert_equal [ false, false, false, false ], checks.map { it["ok"] }
    assert_match "Errno::ENOENT", response.parsed_body["echo"]["error"]
  end

  private
    def checks
      response.parsed_body.values_at("describe", "metrics", "echo", "reopen")
    end
end
