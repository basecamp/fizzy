require "test_helper"

class Fizzy::Saas::CellTest < ActiveSupport::TestCase
  Cell = Fizzy::Saas::Cell

  # Registration is global state, so a test that re-registers has to put the boot-time registration back
  # or every later test in whatever order minitest chose runs without a registered cell.
  teardown { Cell.register! }

  # Development runs the app and its cell as one user, so there is no group to share and chowning into one
  # the app is not in would be EPERM on every conversion.
  test "no group is set when the environment names none" do
    with_env "HOTCELL_GROUP" => nil do
      Cell.register!

      assert_nil HotCell.group
    end
  end

  # A group name, or any typo, is `0` under to_i — root — and the client would chown every descriptor to
  # it. Same reason HOTCELL_ACTIVE_STORAGE raises on a name it does not know: a mistake in a deploy file
  # must not look like a working configuration.
  test "a group that is not a number raises rather than meaning root" do
    with_env "HOTCELL_GROUP" => "hotcell" do
      error = assert_raises(ArgumentError) { Cell.register! }

      assert_match "hotcell", error.message
    end
  end

  # The round trips report what they compared, and nothing above them looked at it — so a cell returning
  # the wrong bytes answered /hotcellz with a 200.
  test "a round trip that returns different bytes is not ok" do
    assert_raises(Cell::CheckFailed) { Cell.send :round_trip, silent_client, "hotcell" }
  end

  # Staged means the worker read a copy on its own scratch rather than the caller's file, so the check
  # proved nothing about the descriptor it was written to prove.
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

  test "a root registers the cell without moving any work" do
    with_env "HOTCELL_ROOT" => "tmp/hotcell", "HOTCELL_ACTIVE_STORAGE" => nil do
      assert Cell.enabled?
      assert_not Cell.processing_attachments?
      assert_empty Cell.active_storage_configuration
    end
  end

  test "the work switch does nothing without a root" do
    with_env "HOTCELL_ROOT" => nil, "HOTCELL_ACTIVE_STORAGE" => "all" do
      assert_not Cell.processing_attachments?
      assert_empty Cell.active_storage_configuration
    end
  end

  test "images moves the transformer and the image analyzer together" do
    configuration = configuration_for "images"

    assert_equal ActiveStorage::HotCell::Client::Transformers::Image::Vips, configuration[:variant_processor]
    assert_equal [ ActiveStorage::HotCell::Client::Analyzers::Image::Vips ],
      configuration[:analyzers].grep(hotcell_classes)
  end

  test "a group that has not moved keeps Rails' own classes" do
    configuration = configuration_for "images"

    assert_equal [ ActiveStorage::Analyzer::VideoAnalyzer, ActiveStorage::Analyzer::AudioAnalyzer ],
      configuration[:analyzers] - configuration[:analyzers].grep(hotcell_classes)
    assert_equal [ ActiveStorage::Previewer::PopplerPDFPreviewer, ActiveStorage::Previewer::MuPDFPreviewer,
                   ActiveStorage::Previewer::VideoPreviewer ], configuration[:previewers]
  end

  test "pdfs moves the PDF previewer and leaves Rails' video previewer behind it" do
    configuration = configuration_for "images,pdfs"

    assert_equal [ ActiveStorage::HotCell::Client::Previewers::Pdf::Mutool,
                   ActiveStorage::Previewer::VideoPreviewer ], configuration[:previewers]
  end

  test "all moves every operation" do
    configuration = configuration_for "all"

    assert_empty configuration[:analyzers] - configuration[:analyzers].grep(hotcell_classes)
    assert_empty configuration[:previewers] - configuration[:previewers].grep(hotcell_classes)
  end

  test "an unknown group raises rather than meaning off" do
    error = assert_raises(ArgumentError) { configuration_for "imgaes" }

    assert_match "imgaes", error.message
  end

  test "the transient class does not descend from the permanent one" do
    assert_not Cell::ProcessingUnavailable <= Cell::UnprocessableAttachment
  end

  test "the client waits at least as long as the cell may take to answer" do
    queue_wait, deadline, kill_and_reply = 10, 120, 1

    assert_operator Cell::TIMEOUT, :>=, queue_wait + deadline + kill_and_reply
  end

  # The gem's default, asserted rather than set, because nothing here should own the number — but a control
  # call on the work timeout is what blanks a host's metrics instead of reporting its cell down. Yabeda
  # collects inside the scrape request, so this has to answer well within one.
  test "control calls are bounded tighter than work calls and than a scrape" do
    scrape_timeout = 10

    assert_operator Cell.cell.control_timeout, :<, scrape_timeout
    assert_operator Cell.cell.control_timeout, :<, Cell::TIMEOUT
  end

  private
    # Answers without writing the output, so the bytes cannot match.
    def silent_client
      Class.new do
        def self.perform_in_hotcell(input, output) = { bytes: 0, staged: false }
      end
    end

    # Returns the right bytes, having read a copy on its own scratch rather than the caller's file.
    def staging_client
      Class.new do
        def self.perform_in_hotcell(input, output)
          output.write File.read(input.path)
          { bytes: 7, staged: true }
        end
      end
    end

    def configuration_for(groups)
      with_env "HOTCELL_ROOT" => "tmp/hotcell", "HOTCELL_ACTIVE_STORAGE" => groups do
        Cell.active_storage_configuration
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
