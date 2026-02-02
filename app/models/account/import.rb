class Account::Import < ApplicationRecord
  broadcasts_refreshes

  belongs_to :account
  belongs_to :identity

  has_one_attached :file

  enum :status, %w[ pending processing completed failed ].index_by(&:itself), default: :pending

  scope :expired, -> { where(completed_at: ...24.hours.ago).or(where(status: :failed, created_at: ...7.days.ago)) }

  def self.cleanup
    expired.each(&:cleanup)
  end

  def process_later
    Account::DataImportJob.perform_later(self)
  end

  def check(start: nil, callback: nil)
    processing!

    ZipFile.read_from(file.blob) do |zip|
      Account::DataTransfer::Manifest.new(account).each_record_set(start: start) do |record_set, last_id|
        record_set.check(from: zip, start: last_id, callback: callback)
      end
    end
  rescue => e
    mark_as_failed
    raise e
  end

  def process(start: nil, callback: nil)
    processing!

    ZipFile.read_from(file.blob) do |zip|
      Account::DataTransfer::Manifest.new(account).each_record_set(start: start) do |record_set, last_id|
        record_set.import(from: zip, start: last_id, callback: callback)
      end
    end

    add_importer_to_all_access_boards
    reconcile_account_storage

    mark_completed
  rescue => e
    mark_as_failed
    raise e
  end

  def cleanup
    destroy
    account.destroy if failed?
  end

  private
    def mark_completed
      update!(status: :completed, completed_at: Time.current)
      ImportMailer.completed(identity, account).deliver_later
    end

    def mark_as_failed
      failed!
      ImportMailer.failed(identity).deliver_later
    end

    def add_importer_to_all_access_boards
      importer = account.users.find_by!(identity: identity)

      account.boards.all_access.find_each do |board|
        board.accesses.grant_to(importer)
      end
    end

    def reconcile_account_storage
      account.boards.each(&:reconcile_storage)
      account.reconcile_storage
      account.materialize_storage
    end
end
