require "shellwords"

class Account::Import < ApplicationRecord
  class InsufficientDiskSpaceError < StandardError; end

  # Peak disk demand beyond the stored zip itself: the imported attachment
  # blobs roughly mirror the zip's contents, plus database growth and margin.
  REQUIRED_DISK_FACTOR = 2

  broadcasts_refreshes

  belongs_to :account
  belongs_to :identity

  has_one_attached :file, dependent: :purge_later

  enum :status, %w[ pending processing completed failed ].index_by(&:itself), default: :pending
  enum :failure_reason, %w[ conflict invalid_export insufficient_disk ].index_by(&:itself), prefix: :failed_due_to, scopes: false

  scope :expired, -> { where(completed_at: ...24.hours.ago).or(where(status: :failed, created_at: ...7.days.ago)) }

  def self.cleanup
    expired.each(&:cleanup)
  end

  def process_later
    Account::DataImportJob.perform_later(self)
  end

  def check(start: nil, callback: nil)
    processing!
    ensure_sufficient_disk_space

    ZipFile.read_from(file.blob) do |zip|
      Account::DataTransfer::Manifest.new(account).each_record_set(start: start) do |record_set, last_id|
        record_set.check(from: zip, start: last_id, callback: callback)
      end
    end
  rescue Account::DataTransfer::RecordSet::ConflictError => e
    mark_as_failed(:conflict)
    raise e
  rescue Account::DataTransfer::RecordSet::IntegrityError, ZipFile::InvalidFileError => e
    mark_as_failed(:invalid_export)
    raise e
  rescue InsufficientDiskSpaceError => e
    mark_as_failed(:insufficient_disk)
    raise e
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
    reconcile_cards_count
    reconcile_account_storage

    mark_completed
  rescue Account::DataTransfer::RecordSet::ConflictError => e
    mark_as_failed(:conflict)
    raise e
  rescue Account::DataTransfer::RecordSet::IntegrityError, ZipFile::InvalidFileError => e
    mark_as_failed(:invalid_export)
    raise e
  rescue => e
    mark_as_failed
    raise e
  end

  def cleanup
    destroy
    account.destroy if failed?
  end

  private
    # Running out of disk mid-import is the worst self-hosted failure mode:
    # Solid Queue shares the web process, so once its own SQLite writes start
    # failing ("database or disk is full") the whole app goes down with the
    # import. Fail fast with a clear reason before consuming the space.
    def ensure_sufficient_disk_space
      return unless file.blob.service.respond_to?(:root)

      required = file.blob.byte_size * REQUIRED_DISK_FACTOR
      available = available_disk_space

      if available && available < required
        raise InsufficientDiskSpaceError, "import needs ~#{required / 1.gigabyte} GB free, found #{available / 1.gigabyte} GB"
      end
    end

    def available_disk_space
      fields = `df -Pk #{Shellwords.escape(file.blob.service.root.to_s)} 2>/dev/null`.lines.last&.split
      fields && fields[3].to_i * 1024
    end

    def mark_completed
      update!(status: :completed, completed_at: Time.current)
      ImportMailer.completed(identity, account).deliver_later
    end

    def mark_as_failed(failure_reason = nil)
      update!(status: :failed, failure_reason: failure_reason)
      ImportMailer.failed(self).deliver_later
    end

    def reconcile_cards_count
      account.update_column :cards_count, [ account.cards_count, account.cards.maximum(:number).to_i ].max
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
