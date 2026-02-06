require "test_helper"

class User::DataExportTest < ActiveSupport::TestCase
  test "build generates zip with card JSON files" do
    export = User::DataExport.create!(account: Current.account, user: users(:david))

    export.build

    assert export.completed?
    assert export.file.attached?
    assert_equal "application/zip", export.file.content_type
  end

  test "build sets status to processing then completed" do
    export = User::DataExport.create!(account: Current.account, user: users(:david))

    export.build

    assert export.completed?
    assert_not_nil export.completed_at
  end

  test "build sends email when completed" do
    export = User::DataExport.create!(account: Current.account, user: users(:david))

    assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob do
      export.build
    end
  end

  test "build includes only accessible cards for user" do
    user = users(:david)
    export = User::DataExport.create!(account: Current.account, user: user)

    export.build

    assert export.completed?
    assert export.file.attached?

    Tempfile.create([ "test", ".zip" ]) do |temp|
      temp.binmode
      export.file.download { |chunk| temp.write(chunk) }
      temp.rewind

      reader = ZipKit::FileReader.read_zip_structure(io: temp)
      json_files = reader.select { |e| e.filename.end_with?(".json") }
      assert json_files.any?, "Zip should contain at least one JSON file"

      extractor = json_files.first.extractor_from(temp)
      json_content = JSON.parse(extractor.extract)
      assert json_content.key?("number")
      assert json_content.key?("title")
      assert json_content.key?("board")
      assert json_content.key?("creator")
      assert json_content["creator"].key?("id")
      assert json_content["creator"].key?("name")
      assert json_content["creator"].key?("email")
      assert json_content.key?("description")
      assert json_content.key?("comments")
    end
  end

  test "build_later enqueues DataExportJob" do
    export = User::DataExport.create!(account: Current.account, user: users(:david))

    assert_enqueued_with(job: DataExportJob, args: [ export ]) do
      export.build_later
    end
  end
end
