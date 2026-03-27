class Account::DataTransfer::Manifest
  attr_reader :account

  def initialize(account)
    @account = account
  end

  def each_record_set(start: nil)
    raise ArgumentError, "No block given" unless block_given?

    started = start.nil?
    record_class, last_id = start if start

    record_sets.each do |record_set|
      if started
        yield record_set
      elsif record_set.model.name == record_class
        started = true
        yield record_set, last_id
      end
    end
  end

  private
    def record_sets
      [
        Account::DataTransfer::AccountRecordSet.new(account),
        Account::DataTransfer::UserRecordSet.new(account),
        *record_sets_for(
          ::User::Settings,
          ::Tag,
          ::Board,
          ::Column
        ),
        Account::DataTransfer::EntropyRecordSet.new(account),
        *record_sets_for(
          ::Board::Publication,
          ::Webhook,
          ::Access,
          ::Card,
          ::Comment,
          ::Step,
          ::Assignment,
          ::Tagging,
          ::Closure,
          ::Card::Goldness,
          ::Card::NotNow,
          ::Card::ActivitySpike,
          ::Watch,
          ::Pin,
          ::Reaction,
          ::Mention,
          ::Filter,
          ::Webhook::DelinquencyTracker,
          ::Event,
          ::Notification,
          ::Notification::Bundle,
          ::Webhook::Delivery
        ),
        Account::DataTransfer::ActiveStorage::BlobRecordSet.new(account),
        record_set_for(::ActiveStorage::VariantRecord),
        Account::DataTransfer::ActiveStorage::AttachmentRecordSet.new(account),
        Account::DataTransfer::ActionText::RichTextRecordSet.new(account),
        Account::DataTransfer::ActiveStorage::FileRecordSet.new(account)
      ].then { set_importable_model_names(it) }
    end

    def record_sets_for(*models)
      models.map do |model|
        record_set_for(model)
      end
    end

    def record_set_for(model)
      Account::DataTransfer::RecordSet.new(account: account, model: model)
    end

    def set_importable_model_names(record_sets)
      model_names = record_sets.filter_map { |record_set| record_set.model&.name }
      record_sets.each { |record_set| record_set.importable_model_names = model_names }
      record_sets
    end
end
