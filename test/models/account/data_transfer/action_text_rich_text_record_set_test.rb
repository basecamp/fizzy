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
end
