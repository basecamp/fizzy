require "test_helper"

class Account::ImportTest < ActiveSupport::TestCase
  test "cleanup deletes completed imports older than 24 hours" do
    identity = identities(:david)
    old_completed = Account::Import.create!(account: Current.account, identity: identity, status: :completed, completed_at: 25.hours.ago)
    recent_completed = Account::Import.create!(account: Current.account, identity: identity, status: :completed, completed_at: 23.hours.ago)

    Account::Import.cleanup

    assert_not Account::Import.exists?(old_completed.id)
    assert Account::Import.exists?(recent_completed.id)
  end

  test "cleanup destroys accounts for failed imports older than 7 days" do
    identity = identities(:david)
    old_failed_account = Account.create!(name: "Old Failed Import")
    old_failed = Account::Import.create!(account: old_failed_account, identity: identity, status: :failed, created_at: 8.days.ago)
    recent_failed_account = Account.create!(name: "Recent Failed Import")
    recent_failed = Account::Import.create!(account: recent_failed_account, identity: identity, status: :failed, created_at: 6.days.ago)

    Account::Import.cleanup

    assert_not Account::Import.exists?(old_failed.id)
    assert_not Account.exists?(old_failed_account.id)
    assert Account::Import.exists?(recent_failed.id)
    assert Account.exists?(recent_failed_account.id)
  end

  test "export and import round-trip preserves account data" do
    source_account = accounts("37s")
    exporter = users(:david)
    identity = exporter.identity

    source_account_digest = account_digest(source_account)

    export = Account::Export.create!(account: source_account, user: exporter)
    export.build

    assert export.completed?

    export_tempfile = Tempfile.new([ "export", ".zip" ])
    export.file.open { |f| FileUtils.cp(f.path, export_tempfile.path) }

    source_account.destroy!

    target_account = Account.create_with_owner(account: { name: "Import Test" }, owner: { identity: identity, name: exporter.name })
    import = Account::Import.create!(identity: identity, account: target_account)
    Current.set(account: target_account) do
      import.file.attach(io: File.open(export_tempfile.path), filename: "export.zip", content_type: "application/zip")
    end

    import.check
    assert_not import.failed?

    import.process
    assert import.completed?

    assert_equal source_account_digest, account_digest(target_account)
  ensure
    export_tempfile&.close
    export_tempfile&.unlink
  end

  test "import reconciles cards count so new cards get correct numbers" do
    source_account = accounts("37s")
    exporter = users(:david)
    identity = exporter.identity
    max_card_number = source_account.cards.maximum(:number)

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

    import.check
    import.process

    target_account.reload
    assert_operator target_account.cards_count, :>=, max_card_number
  ensure
    export_tempfile&.close
    export_tempfile&.unlink
  end

  test "check sets no failure_reason for unexpected errors" do
    import = Account::Import.create!(identity: identities(:david), account: Account.create!(name: "Import Test"))

    assert_raises(NoMethodError) { import.check }

    assert import.failed?
    assert_nil import.failure_reason
  end

  test "check sets failure_reason to invalid_export for non-Fizzy ZIP" do
    target_account = Account.create!(name: "Import Test")
    import = Account::Import.create!(identity: identities(:david), account: target_account)

    # Create a ZIP with no account.json
    tempfile = Tempfile.new([ "bad_export", ".zip" ])
    tempfile.binmode
    writer = ZipFile::Writer.new(tempfile)
    writer.add_file("data/dummy.json", '{"hello": "world"}')
    writer.close
    tempfile.rewind

    Current.set(account: target_account) do
      import.file.attach(io: tempfile, filename: "export.zip", content_type: "application/zip")
    end

    assert_raises(Account::DataTransfer::RecordSet::IntegrityError) { import.check }

    assert import.failed?
    assert_equal "invalid_export", import.failure_reason
  ensure
    tempfile&.close
    tempfile&.unlink
  end

  test "check sets failure_reason to invalid_export for non-ZIP file" do
    target_account = Account.create!(name: "Import Test")
    import = Account::Import.create!(identity: identities(:david), account: target_account)

    tempfile = Tempfile.new([ "not_a_zip", ".zip" ])
    tempfile.write("this is not a zip file at all")
    tempfile.rewind

    Current.set(account: target_account) do
      import.file.attach(io: tempfile, filename: "export.zip", content_type: "application/zip")
    end

    assert_raises(ZipFile::InvalidFileError) { import.check }

    assert import.failed?
    assert_equal "invalid_export", import.failure_reason
  ensure
    tempfile&.close
    tempfile&.unlink
  end

  test "check sets failure_reason to conflict when records already exist" do
    source_account = accounts("37s")
    exporter = users(:david)
    identity = exporter.identity

    export = Account::Export.create!(account: source_account, user: exporter)
    export.build

    export_tempfile = Tempfile.new([ "export", ".zip" ])
    export.file.open { |f| FileUtils.cp(f.path, export_tempfile.path) }

    # Import without destroying the source, so records still exist
    target_account = Account.create_with_owner(account: { name: "Import Test" }, owner: { identity: identity, name: exporter.name })
    import = Account::Import.create!(identity: identity, account: target_account)
    Current.set(account: target_account) do
      import.file.attach(io: File.open(export_tempfile.path), filename: "export.zip", content_type: "application/zip")
    end

    assert_raises(Account::DataTransfer::RecordSet::ConflictError) { import.check }

    assert import.failed?
    assert_equal "conflict", import.failure_reason
  ensure
    export_tempfile&.close
    export_tempfile&.unlink
  end

  private
    def account_digest(account)
      {
        name: account.name,
        board_count: Board.where(account: account).count,
        column_count: Column.where(account: account).count,
        card_count: Card.where(account: account).count,
        comment_count: Comment.where(account: account).count,
        tag_count: Tag.where(account: account).count
      }
    end
end
