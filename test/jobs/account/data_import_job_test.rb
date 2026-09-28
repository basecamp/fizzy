require "test_helper"

class Account::DataImportJobTest < ActiveJob::TestCase
  test "performs import via continuable steps" do
    source_account = accounts("37s")
    exporter = users(:david)
    identity = exporter.identity

    export = Account::Export.create!(account: source_account, user: exporter)
    export.build

    export_tempfile = Tempfile.new([ "export", ".zip" ])
    export.file.open { |f| FileUtils.cp(f.path, export_tempfile.path) }

    source_account.destroy!

    target_account = Account.create_with_owner(account: { name: "Import Test" }, owner: { identity: identity, name: exporter.name })
    import = Account::Import.create!(identity: identity, account: target_account)
    Current.set(account: target_account) do
      import.file.attach(io: File.open(export_tempfile.path), filename: "export.zip", content_type: "application/zip")
    end

    Account::DataImportJob.perform_now(import)

    assert import.reload.completed?
  ensure
    export_tempfile&.close
    export_tempfile&.unlink
  end

  test "resumes the continuation when a transient error is raised after advancing" do
    source_account = accounts("37s")
    exporter = users(:david)
    identity = exporter.identity

    export = Account::Export.create!(account: source_account, user: exporter)
    export.build

    export_tempfile = Tempfile.new([ "export", ".zip" ])
    export.file.open { |f| FileUtils.cp(f.path, export_tempfile.path) }

    source_account.destroy!

    target_account = Account.create_with_owner(account: { name: "Import Test" }, owner: { identity: identity, name: exporter.name })
    import = Account::Import.create!(identity: identity, account: target_account)
    Current.set(account: target_account) do
      import.file.attach(io: File.open(export_tempfile.path), filename: "export.zip", content_type: "application/zip")
    end

    Account::Import.any_instance.stubs(:process).raises(Errno::ECONNRESET)

    assert_enqueued_with(job: Account::DataImportJob) do
      Account::DataImportJob.perform_now(import)
    end
  ensure
    export_tempfile&.close
    export_tempfile&.unlink
  end

  test "discards the job and marks the import failed_due_to_conflict when a crafted export duplicates a unique key" do
    source_account = accounts("37s")
    exporter = users(:david)
    identity = exporter.identity

    boards(:writebook).publish

    export = Account::Export.create!(account: source_account, user: exporter)
    export.build

    export_tempfile = Tempfile.new([ "export", ".zip" ])
    export.file.open { |f| FileUtils.cp(f.path, export_tempfile.path) }

    source_account.destroy!

    tampered_tempfile = duplicate_publication_key_in(export_tempfile)

    target_account = Account.create_with_owner(account: { name: "Import Test" }, owner: { identity: identity, name: exporter.name })
    import = Account::Import.create!(identity: identity, account: target_account)
    Current.set(account: target_account) do
      import.file.attach(io: File.open(tampered_tempfile.path), filename: "export.zip", content_type: "application/zip")
    end

    assert_nothing_raised do
      assert_no_enqueued_jobs only: Account::DataImportJob do
        Account::DataImportJob.perform_now(import)
      end
    end

    assert import.reload.failed_due_to_conflict?
  ensure
    export_tempfile&.close
    export_tempfile&.unlink
    tampered_tempfile&.close
    tampered_tempfile&.unlink
  end

  private
    # Simulates a hand-edited export: an extra board_publications record with a
    # fresh id but a key copied from another record in the same export.
    def duplicate_publication_key_in(export_tempfile)
      tampered = Tempfile.new([ "tampered_export", ".zip" ])
      tampered.binmode

      File.open(export_tempfile.path, "rb") do |file|
        reader = ZipFile::Reader.new(file)
        writer = ZipFile::Writer.new(tampered)

        reader.glob("*").reject { |name| name.end_with?("/") }.each do |entry|
          writer.add_file(entry, reader.read(entry))
        end

        publication_file = reader.glob("data/board_publications/*.json").first
        publication_data = JSON.parse(reader.read(publication_file))
        publication_data["id"] = ActiveRecord::Type::Uuid.generate
        writer.add_file("data/board_publications/#{publication_data['id']}.json", publication_data.to_json)

        writer.close
      end

      tampered.rewind
      tampered
    end
end
