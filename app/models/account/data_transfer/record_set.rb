class Account::DataTransfer::RecordSet
  class IntegrityError < StandardError; end
  class ConflictError < IntegrityError; end

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
        data.slice(*attributes).merge("account_id" => account.id).tap do |record_data|
          record_data["updated_at"] = Time.current if record_data.key?("updated_at")
        end
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
        raise ConflictError, "#{model} record with ID #{data['id']} already exists"
      end

      check_associations_dont_exist(data)
    end

    def check_associations_dont_exist(data)
      model.reflect_on_all_associations(:belongs_to).each do |association|
        foreign_key = association.foreign_key.to_s

        if associated_id = data[foreign_key]
          check_association_doesnt_exist(data, association, associated_id)
        end
      end
    end

    def check_association_doesnt_exist(data, association, associated_id)
      if association.polymorphic?
        type_column = association.foreign_type.to_s
        associated_class = data[type_column].constantize
      else
        associated_class = association.klass
      end

      if associated_class.exists?(id: associated_id)
        raise ConflictError, "#{model} record references existing #{association.name} (#{associated_class}) with ID #{associated_id}"
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
