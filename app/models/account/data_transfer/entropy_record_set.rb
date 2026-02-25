class Account::DataTransfer::EntropyRecordSet < Account::DataTransfer::RecordSet
  def initialize(account)
    super(account: account, model: Entropy)
  end

  private
    def import_batch(files)
      batch_data = files.map do |file|
        data = load(file)
        data.slice(*attributes).merge("account_id" => account.id)
      end

      container_keys = batch_data.map { |d| [ d["container_type"], d["container_id"] ] }
      existing_containers = Entropy
        .where(account_id: account.id)
        .where(container_type: container_keys.map(&:first), container_id: container_keys.map(&:last))
        .pluck(:container_type, :container_id)
        .to_set

      to_update, to_insert = batch_data.partition do |data|
        existing_containers.include?([ data["container_type"], data["container_id"] ])
      end

      to_update.each do |data|
        Entropy
          .find_by(account_id: account.id, container_type: data["container_type"], container_id: data["container_id"])
          .update!(data.slice("auto_postpone_period"))
      end

      Entropy.insert_all!(to_insert) if to_insert.any?
    end
end
