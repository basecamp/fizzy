class Account::DataTransfer::ActionTextRichTextRecordSet < Account::DataTransfer::RecordSet
  ATTRIBUTES = %w[
    account_id
    body
    created_at
    id
    name
    record_id
    record_type
    updated_at
  ].freeze

  def initialize(account)
    super(account: account, model: ActionText::RichText)
  end

  private
    def records
      ActionText::RichText.where(account: account)
    end

    def export_record(rich_text)
      data = rich_text.as_json.merge("body" => convert_sgids_to_gids(rich_text.body))
      zip.add_file "data/action_text_rich_texts/#{rich_text.id}.json", data.to_json
    end

    def files
      zip.glob("data/action_text_rich_texts/*.json")
    end

    def import_batch(files)
      batch_data = files.map do |file|
        data = load(file)
        data["body"] = convert_gids_to_sgids(data["body"])
        data.slice(*ATTRIBUTES).merge("account_id" => account.id)
      end

      ActionText::RichText.insert_all!(batch_data)
    end

    def check_record(file_path)
      data = load(file_path)
      expected_id = File.basename(file_path, ".json")

      unless data["id"].to_s == expected_id
        raise IntegrityError, "ActionTextRichText record ID mismatch: expected #{expected_id}, got #{data['id']}"
      end

      missing = ATTRIBUTES - data.keys
      if missing.any?
        raise IntegrityError, "#{file_path} is missing required fields: #{missing.join(', ')}"
      end

      check_associations_dont_exist(data)
    end

    def convert_sgids_to_gids(content)
      return nil if content.blank?

      content.send(:attachment_nodes).each do |node|
        sgid = SignedGlobalID.parse(node["sgid"], for: ActionText::Attachable::LOCATOR_NAME)

        record = begin
          sgid&.find
        rescue ActiveRecord::RecordNotFound
          nil
        end

        if record&.account_id == account.id
          node["gid"] = record.to_global_id.to_s
          node.remove_attribute("sgid")
        end
      end

      content.fragment.source.to_html
    end

    def convert_gids_to_sgids(html)
      return html if html.blank?

      fragment = Nokogiri::HTML.fragment(html)

      fragment.css("action-text-attachment[gid]").each do |node|
        gid = GlobalID.parse(node["gid"])

        if gid
          record = gid.find
          node["sgid"] = record.attachable_sgid
          node.remove_attribute("gid")
        end
      end

      fragment.to_html
    end
end
