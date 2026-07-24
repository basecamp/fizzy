require "test_helper"

class Account::DataTransfer::ManifestTest < ActiveSupport::TestCase
  setup do
    @manifest = Account::DataTransfer::Manifest.new(accounts("37s"))
  end

  test "each_record_set resumes at the record set identified by the cursor" do
    file_record_set = record_sets.find { |record_set| record_set.is_a?(Account::DataTransfer::ActiveStorage::FileRecordSet) }

    yielded = []
    @manifest.each_record_set(start: [ file_record_set.cursor_key, "storage/somekey" ]) do |record_set, last_id|
      yielded << record_set
    end

    assert_equal 1, yielded.size
    assert_instance_of Account::DataTransfer::ActiveStorage::FileRecordSet, yielded.first
  end

  test "each_record_set distinguishes record sets sharing a model" do
    blob_record_set = record_sets.find { |record_set| record_set.is_a?(Account::DataTransfer::ActiveStorage::BlobRecordSet) }
    file_record_set = record_sets.find { |record_set| record_set.is_a?(Account::DataTransfer::ActiveStorage::FileRecordSet) }

    assert_equal blob_record_set.model, file_record_set.model
    assert_not_equal blob_record_set.cursor_key, file_record_set.cursor_key
  end

  test "each_record_set rejects a cursor that matches no record set" do
    assert_raises(ArgumentError) do
      @manifest.each_record_set(start: [ "Nonexistent/RecordSet", "somefile" ]) { }
    end
  end

  private
    def record_sets
      [].tap do |sets|
        @manifest.each_record_set { |record_set| sets << record_set }
      end
    end
end
