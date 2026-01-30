class Account::DataTransfer::RecordSet
  class IntegrityError < StandardError; end

  IMPORT_BATCH_SIZE = 100

  attr_reader :account, :model, :attributes

  def initialize(account:, model:, attributes: nil)
    @account = account
    @model = model
    @attributes = (attributes || model.column_names).map(&:to_s)
  end

  def export(to:, start: nil)
    with_zip(to) do
      block = lambda do |record|
        export_record(record)
      end

      records.respond_to?(:find_each) ? records.find_each(&block) : records.each(&block)
    end
  end

  def import(from:, start: nil, callback: nil)
    with_zip(from) do
      file_list = files
      file_list = skip_to(file_list, start) if start

      file_list.each_slice(IMPORT_BATCH_SIZE) do |file_batch|
        import_batch(file_batch)
        callback&.call(record_set: self, files: file_batch)
      end
    end
  end

  def check(from:, start: nil, callback: nil)
    with_zip(from) do
      file_list = files
      file_list = skip_to(file_list, start) if start

      file_list.each do |file_path|
        check_record(file_path)
        callback&.call(record_set: self, file: file_path)
      end
    end
  end

  private
    attr_reader :zip

    def with_zip(zip)
      old_zip = @zip
      @zip = zip
      yield
    ensure
      @zip = old_zip
    end

    def records
      model.where(account_id: account.id)
    end

    def export_record(record)
      zip.add_file "data/#{model_dir}/#{record.id}.json", record.to_json
    end

    def files
      zip.glob("data/#{model_dir}/*.json")
    end

    def import_batch(files)
      batch_data = files.map do |file|
        data = load(file)
        data.slice(*attributes).merge("account_id" => account.id)
      end

      model.insert_all!(batch_data)
    end

    def check_record(file_path)
      data = load(file_path)
      expected_id = File.basename(file_path, ".json")

      unless data["id"].to_s == expected_id
        raise IntegrityError, "#{model} record ID mismatch: expected #{expected_id}, got #{data['id']}"
      end

      missing = attributes - data.keys
      if missing.any?
        raise IntegrityError, "#{file_path} is missing required fields: #{missing.join(', ')}"
      end

      if model.exists?(id: data["id"])
        raise IntegrityError, "#{model} record with ID #{data['id']} already exists"
      end

      record = model.new(data.slice(*attributes).merge("account_id" => account.id))
      belongs_to_associations = model.reflect_on_all_associations(:belongs_to).map { |a| a.name.to_s }

      record.validate
      errors = record.errors.reject { |e| belongs_to_associations.include?(e.attribute.to_s) }

      if errors.any?
        raise IntegrityError, "Validation failed for #{model} record ID #{data['id']}: #{errors.map(&:full_message).join(', ')}"
      end
    end

    def skip_to(file_list, last_id)
      index = file_list.index(last_id)

      if index
        file_list[(index + 1)..]
      else
        file_list
      end
    end

    def load(file_path)
      JSON.parse(zip.read(file_path))
    rescue ArgumentError => e
      raise IntegrityError, e.message
    end

    def model_dir
      model.table_name
    end
end
