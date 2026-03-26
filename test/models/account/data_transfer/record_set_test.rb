require "test_helper"

class Account::DataTransfer::RecordSetTest < ActiveSupport::TestCase
  setup do
    @importable_model_names = %w[ Card Board Event ]
  end

  test "check rejects polymorphic type not in the importable models allowlist" do
    event_data = build_event_data(eventable_type: "Identity")

    record_set = Account::DataTransfer::RecordSet.new(account: importing_account, model: Event, importable_model_names: @importable_model_names)

    error = assert_raises(Account::DataTransfer::RecordSet::IntegrityError) do
      record_set.check(from: build_reader(dir: "events", data: event_data))
    end

    assert_match(/unrecognized.*type/i, error.message)
  end

  test "check rejects nonexistent polymorphic type" do
    event_data = build_event_data(eventable_type: "Nonexistent::ClassName")

    record_set = Account::DataTransfer::RecordSet.new(account: importing_account, model: Event, importable_model_names: @importable_model_names)

    error = assert_raises(Account::DataTransfer::RecordSet::IntegrityError) do
      record_set.check(from: build_reader(dir: "events", data: event_data))
    end

    assert_match(/unrecognized.*type/i, error.message)
  end

  test "check rejects non-ActiveRecord class used as polymorphic type" do
    event_data = build_event_data(eventable_type: "ActiveSupport::BroadcastLogger")

    record_set = Account::DataTransfer::RecordSet.new(account: importing_account, model: Event, importable_model_names: @importable_model_names)

    error = assert_raises(Account::DataTransfer::RecordSet::IntegrityError) do
      record_set.check(from: build_reader(dir: "events", data: event_data))
    end

    assert_match(/unrecognized.*type/i, error.message)
  end

  test "check accepts polymorphic type in the importable models allowlist" do
    event_data = build_event_data(eventable_type: "Card")

    record_set = Account::DataTransfer::RecordSet.new(account: importing_account, model: Event, importable_model_names: @importable_model_names)

    assert_nothing_raised do
      record_set.check(from: build_reader(dir: "events", data: event_data))
    end
  end

  private
    def importing_account
      @importing_account ||= Account.create!(name: "Importing Account", external_account_id: 99999999)
    end

    def build_event_data(eventable_type:)
      {
        "id" => "test_event_id_12345678901234",
        "account_id" => "nonexistent_account_id_1234567",
        "board_id" => "nonexistent_board_id_12345678",
        "creator_id" => "nonexistent_user_id_123456789",
        "eventable_type" => eventable_type,
        "eventable_id" => "nonexistent_id_1234567890123",
        "action" => "created",
        "particulars" => "{}",
        "created_at" => Time.current.iso8601,
        "updated_at" => Time.current.iso8601
      }
    end

    def build_reader(dir:, data:)
      tempfile = Tempfile.new([ "import_test", ".zip" ])
      tempfile.binmode

      writer = ZipFile::Writer.new(tempfile)
      writer.add_file("data/#{dir}/#{data['id']}.json", data.to_json)
      writer.close
      tempfile.rewind

      @tempfiles ||= []
      @tempfiles << tempfile

      ZipFile::Reader.new(tempfile)
    end

    def teardown
      @tempfiles&.each { |f| f.close; f.unlink }
      @importing_account&.destroy
    end
end
