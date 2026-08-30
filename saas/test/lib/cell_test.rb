require "test_helper"

class Fizzy::Saas::CellTest < ActiveSupport::TestCase
  Cell = Fizzy::Saas::Cell

  # Registration is global state, so a test that re-registers has to put the boot-time registration back
  # or every later test in whatever order minitest chose runs without a registered cell.
  teardown { Cell.register! }

  test "no group is set when the environment names none" do
    with_env "HOTCELL_GROUP" => nil do
      Cell.register!

      assert_nil HotCell.group
    end
  end

  test "a group that is not a number raises rather than meaning root" do
    with_env "HOTCELL_GROUP" => "hotcell" do
      error = assert_raises(HotCell::ConfigurationError) { Cell.register! }

      assert_match "hotcell", error.message
    end
  end

  test "diagnostics puts nothing on the cell's queue unless asked" do
    Cell.stubs(:echo).raises("echo must not run here")
    Cell.stubs(:reopen).raises("reopen must not run here")

    assert_equal %i[ at host root describe metrics ], Cell.diagnostics.keys
  end

  test "work asks for the round trips as well" do
    assert_equal %i[ at host root describe metrics echo reopen ], Cell.diagnostics(work: true).keys
  end

  test "a round trip that returns different bytes is not ok" do
    assert_raises(Cell::CheckFailed) { Cell.send :round_trip, silent_client, "hotcell" }
  end

  test "a round trip whose input was staged is not ok" do
    error = assert_raises(Cell::CheckFailed) { Cell.send :round_trip, staging_client, "hotcell" }

    assert_match "staged", error.message
  end

  test "the cell is registered even with no root, so callers get an answer rather than an UnregisteredCell" do
    with_env "HOTCELL_ROOT" => nil do
      Cell.register!

      assert_not Cell.enabled?
      assert_not Cell.cell.enabled?
    end
  end

  test "no root moves no work" do
    with_env "HOTCELL_ROOT" => nil do
      assert_not Cell.enabled?
      assert_empty Cell.active_storage_configuration
    end
  end

  # Unstubbed by hand rather than left to mocha, whose automatic unstub runs after this class's
  # teardown re-registers the cell — which would raise exactly the error this test is about.
  test "a deployed app refuses to boot without a cell" do
    Rails.env.stubs(:local?).returns(false)

    with_env "HOTCELL_ROOT" => nil do
      error = assert_raises(HotCell::ConfigurationError) { Cell.register! }

      assert_match "HOTCELL_ROOT", error.message
    end
  ensure
    Rails.env.unstub(:local?)
  end

  test "asset precompilation boots without a cell" do
    Rails.env.stubs(:local?).returns(false)

    with_env "HOTCELL_ROOT" => nil, "SECRET_KEY_BASE_DUMMY" => "1" do
      assert_nothing_raised { Cell.register! }
    end
  ensure
    Rails.env.unstub(:local?)
  end

  test "a root moves every operation to the cell" do
    configuration = with_env("HOTCELL_ROOT" => "tmp/hotcell") { Cell.active_storage_configuration }

    assert_equal ActiveStorage::HotCell::Client::Transformers::Image::Vips, configuration[:variant_processor]
    assert_empty configuration[:analyzers] - configuration[:analyzers].grep(hotcell_classes)
    assert_empty configuration[:previewers] - configuration[:previewers].grep(hotcell_classes)
  end

  test "the transient class does not descend from the permanent one" do
    assert_not Cell::ProcessingUnavailable <= Cell::UnprocessableAttachment
  end

  test "the client waits at least as long as the cell may take to answer" do
    queue_wait, deadline, kill_and_reply = 10, 120, 1

    assert_operator Cell::TIMEOUT, :>=, queue_wait + deadline + kill_and_reply
  end

  test "control calls are bounded tighter than work calls and than a scrape" do
    scrape_timeout = 10

    assert_operator Cell.cell.control_timeout, :<, scrape_timeout
    assert_operator Cell.cell.control_timeout, :<, Cell::TIMEOUT
  end

  private
    def silent_client
      Class.new do
        def self.perform_in_hotcell(input, output) = { bytes: 0, staged: false }
      end
    end

    def staging_client
      Class.new do
        def self.perform_in_hotcell(input, output)
          output.write File.read(input.path)
          { bytes: 7, staged: true }
        end
      end
    end

    def hotcell_classes
      ->(klass) { klass.name.start_with?("ActiveStorage::HotCell::Client::") }
    end

    def with_env(vars)
      originals = vars.keys.index_with { |key| ENV[key] }
      vars.each { |key, value| ENV[key] = value }
      yield
    ensure
      originals.each { |key, value| ENV[key] = value }
    end
end
