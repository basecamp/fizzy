class Account::DataTransfer::UserRecordSet < Account::DataTransfer::RecordSet
  ATTRIBUTES = %w[
    id
    email_address
    name
    role
    active
    verified_at
    created_at
    updated_at
  ]

  def initialize(account)
    super(account: account, model: User)
  end

  private
    def records
      User.where(account: account)
    end

    def export_record(user)
      zip.add_file "data/users/#{user.id}.json", user.as_json.merge(email_address: user.identity&.email_address).to_json
    end

    def files
      zip.glob("data/users/*.json")
    end

    def import_batch(files)
      batch_data = files.map do |file|
        user_data = load(file)
        email_address = user_data.delete("email_address")

        identity = Identity.find_or_create_by!(email_address: email_address) if email_address.present?

        user_data.slice(*ATTRIBUTES).merge(
          "account_id" => account.id,
          "identity_id" => identity&.id
        )
      end

      conflicting_identity_ids = batch_data.pluck("identity_id").compact
      account.users.where(identity_id: conflicting_identity_ids).destroy_all

      User.insert_all!(batch_data)
    end

    def check_record(file_path)
      data = load(file_path)
      expected_id = File.basename(file_path, ".json")

      unless data["id"].to_s == expected_id
        raise IntegrityError, "User record ID mismatch: expected #{expected_id}, got #{data['id']}"
      end

      unless (ATTRIBUTES - data.keys).empty?
        raise IntegrityError, "#{file_path} is missing required fields"
      end
    end
end
