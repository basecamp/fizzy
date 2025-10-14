#
#  This job backs up all the tenant databases using the SQLite Backup API, which should allow the
#  application to continue running against the database while it is backed up.
#
#  ref: https://www.sqlite.org/c3ref/backup_finish.html
#
#  It will keep N files around, like this:
#
#    storage/tenants/development/honcho/db/
#    ├─ main.sqlite3
#    ├─ main.sqlite3.1
#    ├─ main.sqlite3.2
#    ├─ main.sqlite3.3
#    ├─ main.sqlite3.4
#    └─ main.sqlite3.5
#
class SQLiteBackupsJob < ApplicationJob
  DEFAULT_NUMBER_OF_BACKUPS = 5
  DEFAULT_STEP_PAGES = 1024

  def perform(keep: DEFAULT_NUMBER_OF_BACKUPS, step: DEFAULT_STEP_PAGES)
    @failures = []

    ApplicationRecord.with_each_tenant do |tenant|
      perform_file_rollover tenant, keep: keep
      perform_backup tenant, step: step
    end

    if @failures.present?
      raise "SQLiteBackupsJob: failed to backup tenants: #{@failures.join(", ")}"
    end
  end

  private
    def perform_file_rollover(tenant, keep:)
      keep.downto(2) do |j|
        fresher = backup_path(tenant, j - 1)
        staler = backup_path(tenant, j)

        if j == keep && File.exist?(staler)
          FileUtils.rm(staler)
        end

        if File.exist?(fresher)
          # TODO: It may be worth benchmarking whether backing up into the previous backup is faster
          # than backing up into an empty file.
          FileUtils.mv(fresher, staler)
        end
      end
    end

    def perform_backup(tenant, step:)
      ApplicationRecord.with_connection do |conn|
        current_adapter = conn.raw_connection
        backup_db = backup_path(tenant, 1)
        backup_adapter = SQLite3::Database.new(backup_db)
        backup = SQLite3::Backup.new(backup_adapter, "main", current_adapter, "main")

        pages = 0
        elapsed = ActiveSupport::Benchmark.realtime(:float_millisecond) do
          loop do
            status = backup.step(step)
            case status
            when SQLite3::Constants::ErrorCode::DONE
              break
            when SQLite3::Constants::ErrorCode::OK
              total = backup.pagecount
              progress = total - backup.remaining
              Rails.logger.debug { "SQLiteBackupsJob: #{tenant.inspect}: Wrote #{progress} of #{total} pages." }
            when SQLite3::Constants::ErrorCode::BUSY, SQLite3::Constants::ErrorCode::LOCKED
              Rails.logger.debug { "SQLiteBackupsJob: #{tenant.inspect}: Busy, retrying." }
            else
              Rails.logger.error "SQLiteBackupsJob: #{tenant.inspect}: Failed with status #{status}."
              @failures << tenant
            end
          end

          pages = backup.pagecount
          backup.finish
        end

        message = sprintf(
          "SQLiteBackupsJob: %{tenant}: Backup complete in %<elapsed>.1f ms. Wrote %{pages} pages to %{path}",
          tenant: tenant.inspect, path: backup_db.inspect, pages: pages, elapsed: elapsed
        )
        Rails.logger.info message
      end
    end

    def backup_path(tenant, index)
      db_path(tenant) + ".#{index}"
    end

    def db_path(tenant)
      db_config.config_adapter.database_path
    end

    def db_config
      ApplicationRecord.connection_pool.db_config
    end
end
