class Account::DataTransfer::Manifest
  Cursor = Struct.new(:record_class, :last_id)

  attr_reader :account

  def initialize(account)
    @account = account
  end

  def each_record_set(start: nil)
    raise ArgumentError, "No block given" unless block_given?

    record_sets.each do |record_set|
      yield record_set
    end
  end

  private
    def record_sets
      [
        Account::DataTransfer::AccountRecordSet.new(account),
        Account::DataTransfer::UserRecordSet.new(account),
        Account::DataTransfer::RecordSet.new(account: account, model: ::Tag),
        Account::DataTransfer::RecordSet.new(account: account, model: ::Board),
        Account::DataTransfer::RecordSet.new(account: account, model: ::Column),
        Account::DataTransfer::RecordSet.new(account: account, model: ::Entropy),
        Account::DataTransfer::RecordSet.new(account: account, model: ::Board::Publication),
        Account::DataTransfer::RecordSet.new(account: account, model: ::Webhook),
        Account::DataTransfer::RecordSet.new(account: account, model: ::Access),
        Account::DataTransfer::RecordSet.new(account: account, model: ::Card),
        Account::DataTransfer::RecordSet.new(account: account, model: ::Comment),
        Account::DataTransfer::RecordSet.new(account: account, model: ::Step),
        Account::DataTransfer::RecordSet.new(account: account, model: ::Assignment),
        Account::DataTransfer::RecordSet.new(account: account, model: ::Tagging),
        Account::DataTransfer::RecordSet.new(account: account, model: ::Closure),
        Account::DataTransfer::RecordSet.new(account: account, model: ::Card::Goldness),
        Account::DataTransfer::RecordSet.new(account: account, model: ::Card::NotNow),
        Account::DataTransfer::RecordSet.new(account: account, model: ::Card::ActivitySpike),
        Account::DataTransfer::RecordSet.new(account: account, model: ::Watch),
        Account::DataTransfer::RecordSet.new(account: account, model: ::Pin),
        Account::DataTransfer::RecordSet.new(account: account, model: ::Reaction),
        Account::DataTransfer::RecordSet.new(account: account, model: ::Mention),
        Account::DataTransfer::RecordSet.new(account: account, model: ::Filter),
        Account::DataTransfer::RecordSet.new(account: account, model: ::Webhook::DelinquencyTracker),
        Account::DataTransfer::RecordSet.new(account: account, model: ::Event),
        Account::DataTransfer::RecordSet.new(account: account, model: ::Notification),
        Account::DataTransfer::RecordSet.new(account: account, model: ::Notification::Bundle),
        Account::DataTransfer::RecordSet.new(account: account, model: ::Webhook::Delivery),
        Account::DataTransfer::RecordSet.new(account: account, model: ::ActiveStorage::Blob),
        Account::DataTransfer::RecordSet.new(account: account, model: ::ActiveStorage::Attachment),
        Account::DataTransfer::ActionTextRichTextRecordSet.new(account),
        Account::DataTransfer::BlobFileRecordSet.new(account)
      ]
    end
end
