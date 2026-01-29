class Account::Import < ApplicationRecord
  belongs_to :account
  belongs_to :identity

  has_one_attached :file

  enum :status, %w[ pending processing completed failed ].index_by(&:itself), default: :pending

  def process_later
  end

  def process(start: nil, callback: nil)
    processing!
    ensure_downloaded

    Account::DataTransfer::ZipFile.open(download_path) do |zip|
      Account::DataTransfer::Manifest.new(account).each_record_set(start: start&.record_set) do |record_set|
        record_set.import(from: zip, start: start&.record_id, callback: callback)
      end
    end

    mark_completed
  rescue => e
    failed!
    raise e
  end

  def validate(start: nil, callback: nil)
    processing!
    ensure_downloaded

    Account::DataTransfer::ZipFile.open(download_path) do |zip|
      Account::DataTransfer::Manifest.new(account).each_record_set(start: start&.record_set) do |record_set|
        record_set.validate(from: zip, start: start&.record_id, callback: callback)
      end
    end
  end

  private
    def ensure_downloaded
      unless download_path.exist?
        download_path.open("wb") do |f|
          file.download { |chunk| f.write(chunk) }
        end
      end
    end

    def download_path
      Pathname.new("/tmp/account-import-#{id}.zip")
    end

    def mark_completed
      completed!
      # TODO: send email
    end
end
