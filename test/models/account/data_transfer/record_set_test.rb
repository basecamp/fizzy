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

  test "check rejects board publication with a key that already exists" do
    existing_publication = boards(:writebook).publish

    record_set = Account::DataTransfer::Board::PublicationRecordSet.new(importing_account)

    error = assert_raises(Account::DataTransfer::RecordSet::ConflictError) do
      record_set.check(from: build_reader(dir: "board_publications", data: build_publication_data(key: existing_publication.key)))
    end

    assert_match(/key.*already exists/i, error.message)
  end

  test "check accepts board publication with a new key" do
    record_set = Account::DataTransfer::Board::PublicationRecordSet.new(importing_account)

    assert_nothing_raised do
      record_set.check(from: build_reader(dir: "board_publications", data: build_publication_data(key: "brand-new-key")))
    end
  end

  test "check rejects records that duplicate each other's unique values" do
    closures = [
      build_closure_data(id: "test_closure_id_1234567890123", card_id: "nonexistent_card_id_123456789"),
      build_closure_data(id: "test_closure_id_1234567890124", card_id: "nonexistent_card_id_123456789")
    ]

    record_set = Account::DataTransfer::RecordSet.new(account: importing_account, model: Closure)

    error = assert_raises(Account::DataTransfer::RecordSet::IntegrityError) do
      record_set.check(from: build_reader(dir: "closures", data: closures))
    end

    assert_match(/multiple records with the same card_id/i, error.message)
  end

  test "check accepts records with distinct unique values" do
    closures = [
      build_closure_data(id: "test_closure_id_1234567890123", card_id: "nonexistent_card_id_123456789"),
      build_closure_data(id: "test_closure_id_1234567890124", card_id: "nonexistent_card_id_123456780")
    ]

    record_set = Account::DataTransfer::RecordSet.new(account: importing_account, model: Closure)

    assert_nothing_raised do
      record_set.check(from: build_reader(dir: "closures", data: closures))
    end
  end

  test "check rejects records whose unique values collide only under the target account" do
    tags = [
      build_tag_data(id: "test_tag_id_12345678901234567", account_id: "nonexistent_account_a_12345678", title: "Urgent"),
      build_tag_data(id: "test_tag_id_12345678901234568", account_id: "nonexistent_account_b_12345678", title: "Urgent")
    ]

    record_set = Account::DataTransfer::RecordSet.new(account: importing_account, model: Tag)

    error = assert_raises(Account::DataTransfer::RecordSet::IntegrityError) do
      record_set.check(from: build_reader(dir: "tags", data: tags))
    end

    assert_match(/multiple records with the same account_id and title/i, error.message)
  end

  test "check rejects unique values that differ only in case" do
    tags = [
      build_tag_data(id: "test_tag_id_12345678901234567", title: "Urgent"),
      build_tag_data(id: "test_tag_id_12345678901234568", title: "URGENT")
    ]

    record_set = Account::DataTransfer::RecordSet.new(account: importing_account, model: Tag)

    error = assert_raises(Account::DataTransfer::RecordSet::IntegrityError) do
      record_set.check(from: build_reader(dir: "tags", data: tags))
    end

    assert_match(/multiple records with the same account_id and title/i, error.message)
  end

  test "record sets track the model's unique indexes but not the primary key" do
    record_set = Account::DataTransfer::RecordSet.new(account: importing_account, model: Closure)

    assert_includes record_set.send(:unique_key_sets), [ "card_id" ]
    assert_not_includes record_set.send(:unique_key_sets), [ "id" ]
  end

  test "check rejects file names differing only in case" do
    closures = [
      build_closure_data(id: "test_closure_id_123456789012a", card_id: "nonexistent_card_id_123456789"),
      build_closure_data(id: "test_closure_id_123456789012A", card_id: "nonexistent_card_id_123456780")
    ]

    record_set = Account::DataTransfer::RecordSet.new(account: importing_account, model: Closure)

    error = assert_raises(Account::DataTransfer::RecordSet::IntegrityError) do
      record_set.check(from: build_reader(dir: "closures", data: closures))
    end

    assert_match(/multiple files for the same record/i, error.message)
  end

  test "check rejects users that share an email address" do
    users = [
      build_user_data(id: "test_user_id_1234567890123456", email_address: "dupe@example.com"),
      build_user_data(id: "test_user_id_1234567890123457", email_address: "dupe@example.com")
    ]

    record_set = Account::DataTransfer::UserRecordSet.new(importing_account)

    error = assert_raises(Account::DataTransfer::RecordSet::IntegrityError) do
      record_set.check(from: build_reader(dir: "users", data: users))
    end

    assert_match(/multiple records with the same email_address/i, error.message)
  end

  test "check rejects users whose email addresses normalize to the same identity" do
    users = [
      build_user_data(id: "test_user_id_1234567890123456", email_address: "Dupe@Example.com "),
      build_user_data(id: "test_user_id_1234567890123457", email_address: "dupe@example.com")
    ]

    record_set = Account::DataTransfer::UserRecordSet.new(importing_account)

    error = assert_raises(Account::DataTransfer::RecordSet::IntegrityError) do
      record_set.check(from: build_reader(dir: "users", data: users))
    end

    assert_match(/multiple records with the same email_address/i, error.message)
  end

  test "check rejects a user whose ID already exists" do
    user_data = build_user_data(id: users(:david).id, email_address: "someone@example.com")

    record_set = Account::DataTransfer::UserRecordSet.new(importing_account)

    assert_raises(Account::DataTransfer::RecordSet::ConflictError) do
      record_set.check(from: build_reader(dir: "users", data: user_data))
    end
  end

  test "check accepts a board publication without a key" do
    record_set = Account::DataTransfer::Board::PublicationRecordSet.new(importing_account)

    assert_nothing_raised do
      record_set.check(from: build_reader(dir: "board_publications", data: build_publication_data(key: nil)))
    end
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

    def build_tag_data(id:, title:, account_id: "nonexistent_account_id_1234567")
      {
        "id" => id,
        "account_id" => account_id,
        "title" => title,
        "created_at" => Time.current.iso8601,
        "updated_at" => Time.current.iso8601
      }
    end

    def build_closure_data(id:, card_id:)
      {
        "id" => id,
        "account_id" => "nonexistent_account_id_1234567",
        "card_id" => card_id,
        "user_id" => "nonexistent_user_id_123456789",
        "created_at" => Time.current.iso8601,
        "updated_at" => Time.current.iso8601
      }
    end

    def build_user_data(id:, email_address:)
      {
        "id" => id,
        "email_address" => email_address,
        "name" => "Imported User",
        "role" => "member",
        "active" => true,
        "verified_at" => Time.current.iso8601,
        "created_at" => Time.current.iso8601,
        "updated_at" => Time.current.iso8601
      }
    end

    def build_publication_data(key:)
      {
        "id" => "test_publication_id_123456789",
        "account_id" => "nonexistent_account_id_1234567",
        "board_id" => "nonexistent_board_id_12345678",
        "key" => key,
        "created_at" => Time.current.iso8601,
        "updated_at" => Time.current.iso8601
      }
    end

    def build_reader(dir:, data:)
      tempfile = Tempfile.new([ "import_test", ".zip" ])
      tempfile.binmode

      writer = ZipFile::Writer.new(tempfile)
      Array.wrap(data).each do |record|
        writer.add_file("data/#{dir}/#{record['id']}.json", record.to_json)
      end
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
