require "test_helper"

class Account::DataTransfer::ActionText::RichTextRecordSetTest < ActiveSupport::TestCase
  test "check rejects ActionText record referencing existing card in another account" do
    importing_account = Account.create!(name: "Importing Account", external_account_id: 99999999)

    victim_card = cards(:logo)
    assert_not_equal importing_account.id, victim_card.account_id, "Card must belong to a different account"

    # Create a malicious ActionText record that points to the victim's card
    malicious_action_text_data = {
      "id" => "malicious_action_text_id_12345",
      "account_id" => importing_account.id,
      "record_type" => "Card",
      "record_id" => victim_card.id,
      "name" => "description",
      "body" => "<p>Injected content from attacker</p>",
      "created_at" => Time.current.iso8601,
      "updated_at" => Time.current.iso8601
    }

    tempfile = Tempfile.new([ "malicious_import", ".zip" ])
    tempfile.binmode

    writer = ZipFile::Writer.new(tempfile)
    writer.add_file("data/action_text_rich_texts/#{malicious_action_text_data['id']}.json", malicious_action_text_data.to_json)
    writer.close
    tempfile.rewind

    reader = ZipFile::Reader.new(tempfile)

    record_set = Account::DataTransfer::ActionText::RichTextRecordSet.new(importing_account)

    error = assert_raises(Account::DataTransfer::RecordSet::IntegrityError) do
      record_set.check(from: reader)
    end

    assert_match(/references existing record.*Card.*#{victim_card.id}/i, error.message)
  ensure
    tempfile&.close
    tempfile&.unlink
    importing_account&.destroy
  end

  test "transform_body_for_import skips GIDs belonging to another account" do
    victim_tag = tags(:web)
    attacker_account = accounts(:initech)
    assert_not_equal attacker_account.id, victim_tag.account_id

    cross_tenant_gid = victim_tag.to_global_id.to_s
    html = %(<action-text-attachment gid="#{cross_tenant_gid}"></action-text-attachment>)

    record_set = Account::DataTransfer::ActionText::RichTextRecordSet.new(attacker_account)
    result = record_set.send(:transform_body_for_import, html)

    assert_no_match(/sgid=/, result, "Cross-tenant GID must not be converted to SGID")
    assert_match(/gid=/, result, "Original GID should remain unconverted")
  end

  test "transform_body_for_import converts GIDs belonging to the same account" do
    own_tag = tags(:web)
    own_account = accounts(:"37s")
    assert_equal own_account.id, own_tag.account_id

    same_account_gid = own_tag.to_global_id.to_s
    html = %(<action-text-attachment gid="#{same_account_gid}"></action-text-attachment>)

    record_set = Account::DataTransfer::ActionText::RichTextRecordSet.new(own_account)
    result = record_set.send(:transform_body_for_import, html)

    assert_match(/sgid=/, result, "Same-account GID should be converted to SGID")
    assert_no_match(/ gid=/, result, "GID should be removed after SGID conversion")
  end

  test "transform_body_for_import handles non-existent record GIDs gracefully" do
    nonexistent_gid = "gid://fizzy/Tag/00000000000000000000000000"
    html = %(<action-text-attachment gid="#{nonexistent_gid}"></action-text-attachment>)

    record_set = Account::DataTransfer::ActionText::RichTextRecordSet.new(accounts(:"37s"))
    result = record_set.send(:transform_body_for_import, html)

    assert_no_match(/sgid=/, result, "Non-existent record should not produce SGID")
  end

  test "replace_account_slugs rewrites relative URLs with account slug" do
    target_account = accounts(:"37s")
    source_slug = "9999999"
    target_slug = AccountSlug.encode(target_account.external_account_id)

    html = %(<p>See <a href="/#{source_slug}/cards/42">card 42</a></p>)

    record_set = Account::DataTransfer::ActionText::RichTextRecordSet.new(target_account)
    result = record_set.send(:transform_body_for_import, html)

    assert_includes result, "/#{target_slug}/cards/42"
    assert_not_includes result, source_slug
  end

  test "replace_account_slugs leaves absolute URLs alone" do
    target_account = accounts(:"37s")

    html = %(<p>See <a href="https://fizzy.app/9999999/boards/7">board</a></p>)

    record_set = Account::DataTransfer::ActionText::RichTextRecordSet.new(target_account)
    result = record_set.send(:transform_body_for_import, html)

    assert_includes result, "https://fizzy.app/9999999/boards/7"
  end

  test "replace_account_slugs leaves plain text alone" do
    target_account = accounts(:"37s")

    html = "<p>Nothing to rewrite here</p>"

    record_set = Account::DataTransfer::ActionText::RichTextRecordSet.new(target_account)
    result = record_set.send(:transform_body_for_import, html)

    assert_equal html, result
  end

  test "relativize_urls strips instance host from absolute URLs" do
    with_default_url_host("fizzy.example.com") do
      record_set = Account::DataTransfer::ActionText::RichTextRecordSet.new(accounts(:"37s"))

      html = %(<p>See <a href="https://fizzy.example.com/123/cards/42">card</a></p>)
      result = record_set.send(:relativize_urls, html)

      assert_includes result, %(/123/cards/42)
      assert_not_includes result, "fizzy.example.com"
    end
  end

  test "relativize_urls preserves query and fragment" do
    with_default_url_host("fizzy.example.com") do
      record_set = Account::DataTransfer::ActionText::RichTextRecordSet.new(accounts(:"37s"))

      html = %(<p><a href="https://fizzy.example.com/123/cards/42?tab=comments#comment_1">link</a></p>)
      result = record_set.send(:relativize_urls, html)

      assert_includes result, "/123/cards/42?tab=comments#comment_1"
      assert_not_includes result, "fizzy.example.com"
    end
  end

  test "relativize_urls leaves external URLs alone" do
    with_default_url_host("fizzy.example.com") do
      record_set = Account::DataTransfer::ActionText::RichTextRecordSet.new(accounts(:"37s"))

      html = %(<p><a href="https://github.com/some/repo">link</a></p>)
      result = record_set.send(:relativize_urls, html)

      assert_includes result, "https://github.com/some/repo"
    end
  end

  test "relativize_urls is a no-op when host is not configured" do
    with_default_url_host(nil) do
      record_set = Account::DataTransfer::ActionText::RichTextRecordSet.new(accounts(:"37s"))

      html = %(<p><a href="https://fizzy.example.com/123/cards/42">link</a></p>)
      result = record_set.send(:relativize_urls, html)

      assert_includes result, "https://fizzy.example.com/123/cards/42"
    end
  end

  private
    def with_default_url_host(host)
      options = Rails.application.routes.default_url_options
      had_key = options.key?(:host)
      original = options[:host]
      options[:host] = host
      yield
    ensure
      if had_key
        options[:host] = original
      else
        options.delete(:host)
      end
    end
end
