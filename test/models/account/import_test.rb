require "test_helper"

class Account::ImportTest < ActiveSupport::TestCase
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
