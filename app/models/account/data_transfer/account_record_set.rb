class Account::DataTransfer::AccountRecordSet < Account::DataTransfer::RecordSet
  ACCOUNT_ATTRIBUTES = %w[
    join_code
    name
  ]

  JOIN_CODE_ATTRIBUTES = %w[
    code
    usage_count
    usage_limit
  ]

  def initialize(account)
    super(account: account, model: Account)
  end

  private
    def records
      [ account ]
    end

    def export_record(account)
      zip.add_file "data/account.json", account.as_json.merge(join_code: account.join_code.as_json).to_json
    end

    def files
      [ "data/account.json" ]
    end

    def import_batch(files)
      account_data = load(files.first)
      join_code_data = account_data.delete("join_code")

      account.update!(name: account_data.fetch("name"), cards_count: account_data.fetch("cards_count", 0))
      account.join_code.update!(join_code_data.slice("usage_count", "usage_limit"))
      account.join_code.update(code: join_code_data.fetch("code"))
    end

    def check_record(file_path)
      data = load(file_path)

      unless (ACCOUNT_ATTRIBUTES - data.keys).empty?
        raise IntegrityError, "Account record missing required fields"
      end

      unless data.key?("join_code")
        raise IntegrityError, "Account record missing 'join_code' field"
      end

      unless data["join_code"].is_a?(Hash)
        raise IntegrityError, "'join_code' field must be a JSON object"
      end

      unless (JOIN_CODE_ATTRIBUTES - data["join_code"].keys).empty?
        raise IntegrityError, "'join_code' field missing required keys"
      end
    end
end
