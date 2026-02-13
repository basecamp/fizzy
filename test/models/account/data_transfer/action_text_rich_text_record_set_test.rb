require "test_helper"

class Account::DataTransfer::ActionTextRichTextRecordSetTest < ActiveSupport::TestCase
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

    record_set = Account::DataTransfer::ActionTextRichTextRecordSet.new(importing_account)

    error = assert_raises(Account::DataTransfer::RecordSet::IntegrityError) do
      record_set.check(from: reader)
    end

    assert_match(/references existing record.*Card.*#{victim_card.id}/i, error.message)
  ensure
    tempfile&.close
    tempfile&.unlink
    importing_account&.destroy
  end

  test "convert_gids_to_sgids skips GIDs belonging to another account" do
    victim_tag = tags(:web)
    attacker_account = accounts(:initech)
    assert_not_equal attacker_account.id, victim_tag.account_id

    cross_tenant_gid = victim_tag.to_global_id.to_s
    html = %(<action-text-attachment gid="#{cross_tenant_gid}"></action-text-attachment>)

    record_set = Account::DataTransfer::ActionTextRichTextRecordSet.new(attacker_account)
    result = record_set.send(:convert_gids_to_sgids, html)

    assert_no_match(/sgid=/, result, "Cross-tenant GID must not be converted to SGID")
    assert_match(/gid=/, result, "Original GID should remain unconverted")
  end

  test "convert_gids_to_sgids converts GIDs belonging to the same account" do
    own_tag = tags(:web)
    own_account = accounts(:"37s")
    assert_equal own_account.id, own_tag.account_id

    same_account_gid = own_tag.to_global_id.to_s
    html = %(<action-text-attachment gid="#{same_account_gid}"></action-text-attachment>)

    record_set = Account::DataTransfer::ActionTextRichTextRecordSet.new(own_account)
    result = record_set.send(:convert_gids_to_sgids, html)

    assert_match(/sgid=/, result, "Same-account GID should be converted to SGID")
    assert_no_match(/ gid=/, result, "GID should be removed after SGID conversion")
  end

  test "convert_gids_to_sgids handles non-existent record GIDs gracefully" do
    nonexistent_gid = "gid://fizzy/Tag/00000000000000000000000000"
    html = %(<action-text-attachment gid="#{nonexistent_gid}"></action-text-attachment>)

    record_set = Account::DataTransfer::ActionTextRichTextRecordSet.new(accounts(:"37s"))
    result = record_set.send(:convert_gids_to_sgids, html)

    assert_no_match(/sgid=/, result, "Non-existent record should not produce SGID")
  end
end
