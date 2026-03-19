require "test_helper"

class Account::DataTransfer::ActiveStorage::AttachmentRecordSetTest < ActiveSupport::TestCase
  test "check skips attachments for internal record types" do
    attachment_data = build_attachment_data(record_type: "ActiveStorage::VariantRecord")

    record_set = Account::DataTransfer::ActiveStorage::AttachmentRecordSet.new(importing_account)
    record_set.importable_model_names = %w[ActiveStorage::Attachment ActiveStorage::Blob Card]

    assert_nothing_raised do
      record_set.check(from: build_reader(data: attachment_data))
    end
  end

  test "import skips attachments for internal record types" do
    variant_attachment = build_attachment_data(record_type: "ActiveStorage::VariantRecord")
    card_attachment = build_attachment_data(record_type: "Card")

    record_set = Account::DataTransfer::ActiveStorage::AttachmentRecordSet.new(importing_account)

    record_set.import(from: build_reader(data: [ variant_attachment, card_attachment ]))

    assert_not ActiveStorage::Attachment.exists?(id: variant_attachment["id"])
    assert ActiveStorage::Attachment.exists?(id: card_attachment["id"])
  end

  private
    def importing_account
      @importing_account ||= Account.create!(name: "Importing Account", external_account_id: 88888888)
    end

    def build_attachment_data(record_type:)
      {
        "id" => ActiveRecord::Type::Uuid.generate,
        "account_id" => ActiveRecord::Type::Uuid.generate,
        "blob_id" => ActiveRecord::Type::Uuid.generate,
        "created_at" => Time.current.iso8601,
        "name" => "file",
        "record_id" => ActiveRecord::Type::Uuid.generate,
        "record_type" => record_type
      }
    end

    def build_reader(data:)
      data = Array.wrap(data)
      tempfile = Tempfile.new([ "test_export", ".zip" ])
      tempfile.binmode

      writer = ZipFile::Writer.new(tempfile)
      data.each do |attachment|
        writer.add_file("data/active_storage_attachments/#{attachment['id']}.json", attachment.to_json)
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
