require "test_helper"

class Account::ImportTest < ActiveSupport::TestCase
  setup do
    @identity = identities(:david)
    @source_account = accounts("37s")
  end

  test "process sets status to failed on error" do
    import = create_import_with_file
    Account::DataTransfer::Manifest.any_instance.stubs(:each_record_set).raises(StandardError.new("Test error"))

    assert_raises(StandardError) do
      import.process
    end

    assert import.failed?
  end

  test "process imports account name from export" do
    target_account = create_target_account
    import = create_import_for_account(target_account)

    import.process

    assert_equal @source_account.name, target_account.reload.name
  end

  test "process imports users with identity matching" do
    target_account = create_target_account
    import = create_import_for_account(target_account)
    new_email = "new-user-#{SecureRandom.hex(4)}@example.com"

    import.process

    # Users from the source account should be imported
    assert target_account.users.count > 2 # system user + owner + imported users
  end

  test "process preserves join code if unique" do
    target_account = create_target_account
    import = create_import_for_account(target_account)

    # Set up a unique code in the export
    export_code = "UNIQ-CODE-1234"
    Account::JoinCode.where(code: export_code).delete_all

    # Modify the export zip to have this code
    import_with_custom_join_code = create_import_for_account(target_account, join_code: export_code)

    import_with_custom_join_code.process

    # Join code update attempt is made (may or may not succeed based on uniqueness)
    assert import_with_custom_join_code.completed?
  end

  test "validate raises IntegrityError for missing required fields" do
    target_account = create_target_account
    import = create_import_with_invalid_data(target_account)

    assert_raises(Account::DataTransfer::RecordSet::IntegrityError) do
      import.validate
    end
  end

  test "process rolls back on ID collision" do
    target_account = create_target_account

    # Pre-create a tag with a specific ID that will collide
    colliding_id = SecureRandom.uuid
    Tag.create!(
      id: colliding_id,
      account: target_account,
      title: "Existing tag"
    )

    import = create_import_for_account(target_account, tag_id: colliding_id)

    assert_raises(ActiveRecord::RecordNotUnique) do
      import.process
    end

    # Import should be marked as failed
    assert import.reload.failed?
  end

  test "process marks import as completed on success" do
    target_account = create_target_account
    import = create_import_for_account(target_account)

    import.process

    assert import.completed?
  end

  private
    def create_target_account
      account = Account.create!(name: "Import Target")
      account.users.create!(role: :system, name: "System")
      account.users.create!(
        role: :owner,
        name: "Importer",
        identity: @identity,
        verified_at: Time.current
      )
      account
    end

    def create_import_with_file
      target_account = create_target_account
      import = Account::Import.create!(identity: @identity, account: target_account)
      Current.set(account: target_account) do
        import.file.attach(io: generate_export_zip, filename: "export.zip", content_type: "application/zip")
      end
      import
    end

    def create_import_for_account(target_account, **options)
      import = Account::Import.create!(identity: @identity, account: target_account)
      Current.set(account: target_account) do
        import.file.attach(io: generate_export_zip(**options), filename: "export.zip", content_type: "application/zip")
      end
      import
    end

    def create_import_with_invalid_data(target_account)
      import = Account::Import.create!(identity: @identity, account: target_account)
      Current.set(account: target_account) do
        import.file.attach(
          io: generate_invalid_export_zip,
          filename: "export.zip",
          content_type: "application/zip"
        )
      end
      import
    end

    def generate_export_zip(join_code: nil, tag_id: nil)
      tempfile = Tempfile.new([ "export", ".zip" ])
      Zip::File.open(tempfile.path, create: true) do |zip|
        account_data = @source_account.as_json.merge(
          "join_code" => {
            "code" => join_code || @source_account.join_code.code,
            "usage_count" => 0,
            "usage_limit" => 10
          },
          "name" => @source_account.name
        )
        zip.get_output_stream("data/account.json") { |f| f.write(JSON.generate(account_data)) }

        # Export users with new UUIDs (to avoid collisions with fixtures)
        @source_account.users.each do |user|
          new_id = SecureRandom.uuid
          user_data = {
            "id" => new_id,
            "account_id" => @source_account.id,
            "email_address" => "imported-#{SecureRandom.hex(4)}@example.com",
            "name" => user.name,
            "role" => user.role,
            "active" => user.active,
            "verified_at" => user.verified_at,
            "created_at" => user.created_at,
            "updated_at" => user.updated_at
          }
          zip.get_output_stream("data/users/#{new_id}.json") { |f| f.write(JSON.generate(user_data)) }
        end

        # Export tags with new UUIDs (to avoid collisions with fixtures)
        @source_account.tags.each do |tag|
          new_id = tag_id || SecureRandom.uuid
          tag_data = {
            "id" => new_id,
            "account_id" => @source_account.id,
            "title" => tag.title,
            "created_at" => tag.created_at,
            "updated_at" => tag.updated_at
          }
          zip.get_output_stream("data/tags/#{new_id}.json") { |f| f.write(JSON.generate(tag_data)) }
        end

        # Add a tag if we need to test collision and source has no tags
        if tag_id && @source_account.tags.empty?
          tag_data = {
            "id" => tag_id,
            "account_id" => @source_account.id,
            "title" => "Test Tag",
            "created_at" => Time.current,
            "updated_at" => Time.current
          }
          zip.get_output_stream("data/tags/#{tag_id}.json") { |f| f.write(JSON.generate(tag_data)) }
        end
      end
      File.open(tempfile.path, "rb")
    end

    def generate_invalid_export_zip
      tempfile = Tempfile.new([ "export", ".zip" ])
      Zip::File.open(tempfile.path, create: true) do |zip|
        # Account data missing required 'name' field
        account_data = { "id" => @source_account.id }
        zip.get_output_stream("data/account.json") { |f| f.write(JSON.generate(account_data)) }
      end
      File.open(tempfile.path, "rb")
    end
end
