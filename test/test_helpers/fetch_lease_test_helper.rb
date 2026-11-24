# The lease is off in tests (config/environments/test.rb), so parallel workers
# don't contend for it; these tests turn it on, against whichever engine the
# suite runs on: named locks on MySQL, slot files on SQLite.
module FetchLeaseTestHelper
  extend ActiveSupport::Concern

  included do
    include OauthAvailabilityTestHelper

    setup do
      @slots_directory = Dir.mktmpdir
      Oauth::ClientMetadata::FetchLease.stubs(:slots_directory).returns(@slots_directory)
    end

    teardown do
      FileUtils.remove_entry(@slots_directory)

      # A test whose release failed leaves its named lock on the connection
      # the next test uses.
      Oauth::Client.with_connection do |connection|
        connection.query_value("SELECT RELEASE_ALL_LOCKS()") if connection.adapter_name.match?(/mysql/i)
      end
    end
  end

  private
    def with_lease(&block)
      with_oauth_config(cimd_fetch_lease: true, &block)
    end

    # Asked from outside the holder: on MySQL a session may take a lock it
    # already holds, so admitting again on the same connection proves nothing.
    def slot_free?(index)
      Oauth::Client.with_connection do |connection|
        if connection.adapter_name.match?(/mysql/i)
          name = Oauth::ClientMetadata::FetchLease::NamedLocks.lock_name(connection, index)
          connection.query_value("SELECT IS_FREE_LOCK(#{connection.quote(name)})") == 1
        else
          File.open(File.join(@slots_directory, "slot-#{index}.lock"), File::RDWR | File::CREAT) do |file|
            file.flock(File::LOCK_EX | File::LOCK_NB).tap { file.flock(File::LOCK_UN) }
          end
        end
      end
    end

    def lease_events(&block)
      events = []
      callback = ->(event) { events << [ event.name, event.payload ] }
      ActiveSupport::Notifications.subscribed(callback, /\Acimd_lease/, &block)
      events
    end
end
