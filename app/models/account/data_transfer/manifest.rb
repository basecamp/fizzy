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
        *build_record_sets(::User::Settings, ::Tag, ::Board, ::Column),
        Account::DataTransfer::EntropyRecordSet.new(account),
        *build_record_sets(
          ::Board::Publication, ::Webhook, ::Access, ::Card, ::Comment, ::Step,
          ::Assignment, ::Tagging, ::Closure, ::Card::Goldness, ::Card::NotNow,
          ::Card::ActivitySpike, ::Watch, ::Pin, ::Reaction, ::Mention,
          ::Filter, ::Webhook::DelinquencyTracker, ::Event,
          ::Notification, ::Notification::Bundle, ::Webhook::Delivery
        ),
        Account::DataTransfer::ActiveStorage::BlobRecordSet.new(account),
        *build_record_sets(::ActiveStorage::Attachment),
        Account::DataTransfer::ActionText::RichTextRecordSet.new(account),
        Account::DataTransfer::ActiveStorage::FileRecordSet.new(account)
      ]
    end

    def build_record_sets(*models)
      models.map do |model|
        Account::DataTransfer::RecordSet.new(account: account, model: model)
      end
    end
end
