class Account::DataTransfer::ActionText::RichTextRecordSet < Account::DataTransfer::RecordSet
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
    super(account: account, model: ::ActionText::RichText)
  end

  private
    def records
      ::ActionText::RichText.where(account: account)
    end

    def export_record(rich_text)
      data = rich_text.as_json.merge("body" => transform_body_for_export(rich_text.body))
      zip.add_file "data/action_text_rich_texts/#{rich_text.id}.json", data.to_json
    end

    def files
      zip.glob("data/action_text_rich_texts/*.json")
    end

    def import_batch(files)
      batch_data = files.map do |file|
        data = load(file)
        data["body"] = transform_body_for_import(data["body"])
        data.slice(*ATTRIBUTES).merge("account_id" => account.id)
      end

      ::ActionText::RichText.insert_all!(batch_data)
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

    def transform_body_for_export(content)
      return nil if content.blank?

      html = convert_sgids_to_gids(content)
      relativize_urls(html)
    end

    def convert_sgids_to_gids(content)
      content.send(:attachment_nodes).each do |node|
        sgid = SignedGlobalID.parse(node["sgid"], for: ::ActionText::Attachable::LOCATOR_NAME)

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

    def relativize_urls(html)
      host = Rails.application.routes.default_url_options[:host]
      return html unless host

      fragment = Nokogiri::HTML.fragment(html)

      fragment.css("a[href]").each do |link|
        uri = URI.parse(link["href"]) rescue nil

        if uri.respond_to?(:host) && uri.host == host
          link["href"] = uri.path
          link["href"] += "?#{uri.query}" if uri.query
          link["href"] += "##{uri.fragment}" if uri.fragment
        end
      end

      fragment.to_html
    end

    def transform_body_for_import(body)
      return body if body.blank?

      Nokogiri::HTML.fragment(body)
        .then { convert_gids_to_sgids(it) }
        .then { replace_account_slugs(it) }
        .to_html
    end

    def convert_gids_to_sgids(fragment)
      fragment.css("action-text-attachment[gid]").each do |node|
        gid = GlobalID.parse(node["gid"])

        if gid
          record = begin
            gid.find
          rescue ActiveRecord::RecordNotFound
            nil
          end

          if record&.account_id == account.id
            node["sgid"] = record.attachable_sgid
            node.remove_attribute("gid")
          end
        end
      end

      fragment
    end

    def replace_account_slugs(fragment)
      fragment.css("a[href]").each do |link|
        match = link["href"].match(AccountSlug::PATH_INFO_MATCH)

        if match
          path = match.post_match.presence || "/"
          valid_path = Rails.application.routes.recognize_path(path) rescue nil
          link["href"] = "#{account.slug}#{path}" if valid_path
        end
      end

      fragment
    end
end
