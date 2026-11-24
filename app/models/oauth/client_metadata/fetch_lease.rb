# A bound on metadata document fetches in flight across every process of one
# install: SLOTS at once. Ported from bc3's Oauth::ClientMetadata::FetchLease.
# The fetcher's Bulkhead bounds one process; with several processes, each
# within its own bulkhead, only a shared lease bounds the whole. A lease, not a
# rate window: a window would admit its whole allowance at once, and nearly
# double it across a window boundary.
#
# Fail-fast: no free slot is an immediate :overloaded (a 503 to retry), never a
# wait. Fail-closed: a backend error refuses, so a backend outage turns
# metadata document intake into 503s while fresh rows keep resolving without a
# fetch, rather than fetching without bound.
#
# Off unless config.x.oauth.cimd_fetch_lease says otherwise, which it does
# only by following config.x.oauth.cimd_open_registration: the lease adds a
# dependency that refuses fetches when it fails, so it arrives with the open
# tier rather than before it. Tests turn it off, and its own tests on.
#
# Two backends, by database engine, since there is no shared cache that can
# take a lock atomically (Solid Cache's write(unless_exist: true) can't: two
# writers of an absent key both upsert, and both read success):
#
# - MySQL: named locks, GET_LOCK(name, 0) on the connection this request
#   holds, released on that same connection. Atomic, and tied to the session:
#   a crashed process's session ends, and its locks with it. The connection is
#   held from acquisition to release, so no other thread can take it from the
#   pool and, since a session may take a lock it already holds, take our slot
#   again. Lock names are server-wide, so each carries the environment and the
#   database. A GET reads from a replica, and GET_LOCK is a SELECT, so a
#   consent render locks on the replica and an authorization POST on the
#   primary: the bound is SLOTS per database server, not per install.
# - SQLite: flock'd slot files beside the database. Acquisition is atomic in
#   the kernel, and a lock goes with its file descriptor, process death
#   included. Beside the database because that's the volume every app process
#   of the install shares, overlapping containers in a rolling deploy included;
#   a container-local path would quietly give each container its own slots.
#
# Any other adapter refuses: a pool private to each process isn't the bound.
class Oauth::ClientMetadata::FetchLease
  SLOTS = 6

  class << self
    # Yields true holding a slot, released on every exit, or false when the
    # slots are spent or the backend failed. Yields true, holding nothing,
    # while the lease is off.
    def admit(&block)
      if !enabled?
        yield true
      elsif mysql?
        # Held from acquisition to release; see NamedLocks.
        Oauth::Client.with_connection { |connection| admit_on(connection, &block) }
      else
        admit_on(nil, &block)
      end
    end

    def enabled?
      if config.cimd_fetch_lease.nil?
        config.cimd_open_registration == true
      else
        config.cimd_fetch_lease == true
      end
    end

    # Beside the SQLite database (see above), or under tmp where the database
    # has no file of its own (in memory).
    def slots_directory
      if path = sqlite_database_path
        Pathname.new(path).dirname.join("oauth_cimd_fetch_lease")
      else
        Rails.root.join("tmp", "oauth_cimd_fetch_lease")
      end
    end

    private
      def admit_on(connection)
        if lease = acquire(connection)
          begin
            record :admitted
            yield true
          ensure
            release lease
          end
        else
          record :refused
          yield false
        end
      end

      def acquire(connection)
        if mysql?
          NamedLocks.acquire(connection)
        elsif sqlite?
          FileSlots.acquire(slots_directory)
        end
      rescue StandardError => error
        report_failure "acquire", error
        nil
      end

      def mysql?
        adapter.match?(/mysql/i)
      end

      def sqlite?
        adapter.match?(/sqlite/i)
      end

      # From the configuration, so that choosing a backend takes no connection.
      def adapter
        Oauth::Client.connection_db_config.adapter.to_s
      end

      # A failed release mustn't replace the caller's own outcome, or its
      # exception. A named lock whose release raised is likeliest gone already,
      # with the session that held it; a session still alive is ended, outside
      # a transaction, so the slot isn't held until the connection closes.
      def release(lease)
        unless lease.release
          report_failure "release", nil
        end
      rescue StandardError => error
        report_failure "release", error
        lease.abandon
      end

      # SQLite's own answer for the file it opened, rather than one parsed from
      # the configuration. Blank for a temporary or in-memory database.
      def sqlite_database_path
        if sqlite?
          Oauth::Client.with_connection { |connection| connection.raw_connection.filename.presence }
        end
      end

      # Telemetry is best-effort: it must never cost an admission its yield,
      # or strand a held slot.
      def record(outcome)
        ActiveSupport::Notifications.instrument "cimd_lease.oauth", outcome: outcome
      rescue StandardError => error
        report_failure "record", error
      end

      # Never raises: its callers are rescues and ensures. A refusal reads the
      # same whether the slots were spent or the backend failed; this is what
      # tells them apart.
      def report_failure(operation, error)
        ActiveSupport::Notifications.instrument "cimd_lease_error.oauth", operation: operation
        Rails.logger.warn "[Oauth::ClientMetadata::FetchLease] #{operation} failed closed#{": #{error.class}" if error}"
      rescue StandardError
        nil
      end

      def config
        Rails.application.config.x.oauth
      end
  end

  module NamedLocks
    def self.acquire(connection)
      SLOTS.times do |index|
        name = lock_name(connection, index)
        return Lease.new(connection, name) if connection.get_advisory_lock(name, 0)
      end

      nil
    end

    # Within MySQL's 64 characters: the database name is digested, since it can
    # be long.
    def self.lock_name(connection, index)
      "fizzy:cimd_fetch:#{Rails.env}:#{Digest::SHA256.hexdigest(connection.current_database.to_s).first(12)}:#{index}"
    end

    Lease = Struct.new(:connection, :name) do
      # True when this session held the lock. False or nil when it didn't,
      # which means the lock was already lost, with a reconnected session.
      def release
        connection.release_advisory_lock(name)
      end

      def abandon
        connection.disconnect! unless connection.transaction_open?
      rescue StandardError
        nil
      end
    end
  end

  module FileSlots
    def self.acquire(directory)
      FileUtils.mkdir_p(directory)

      SLOTS.times do |index|
        file = File.open(File.join(directory, "slot-#{index}.lock"), File::RDWR | File::CREAT, 0o644)

        if file.flock(File::LOCK_EX | File::LOCK_NB)
          return Lease.new(file)
        else
          file.close
        end
      end

      nil
    end

    # Releases by closing, not by LOCK_UN, which would unlock the open file
    # description itself, a forked child's copy unlocking its parent's.
    Lease = Struct.new(:file) do
      def release
        file.close
        true
      end

      def abandon
        nil
      end
    end
  end
end
