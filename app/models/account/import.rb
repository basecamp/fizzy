class Account::Import < ApplicationRecord
  broadcasts_refreshes

  belongs_to :account
  belongs_to :identity

  has_one_attached :file

  enum :status, %w[ pending processing completed failed ].index_by(&:itself), default: :pending

  def process_later
    ImportAccountDataJob.perform_later(self)
  end

  def check(start: nil, callback: nil)
    processing!

    ZipFile.read_from(file.blob) do |zip|
      Account::DataTransfer::Manifest.new(account).each_record_set(start: start) do |record_set, last_id|
        record_set.check(from: zip, start: last_id, callback: callback)
      end
    end
  end

  def process(start: nil, callback: nil)
    processing!

    ZipFile.read_from(file.blob) do |zip|
      Account::DataTransfer::Manifest.new(account).each_record_set(start: start) do |record_set, last_id|
        record_set.import(from: zip, start: last_id, callback: callback)
      end
    end

    mark_completed
  rescue => e
    mark_as_failed
    raise e
  end

  private
    def mark_completed
      completed!
      ImportMailer.completed(identity, account).deliver_later
    end

    def mark_as_failed
      failed!
      ImportMailer.failed(identity).deliver_later
    end
end
