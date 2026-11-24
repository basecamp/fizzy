require "test_helper"

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

class Oauth::ClientMetadata::FetchLeaseTest < ActiveSupport::TestCase
  include FetchLeaseTestHelper

  test "off, admits everything and holds nothing" do
    with_oauth_config(cimd_fetch_lease: false) do
      (Oauth::ClientMetadata::FetchLease::SLOTS + 2).times do
        Oauth::ClientMetadata::FetchLease.admit do |admitted|
          assert admitted
          assert slot_free?(0)
        end
      end
    end
  end

  test "on only with open registration, unless set" do
    with_oauth_config(cimd_fetch_lease: nil, cimd_open_registration: false) { assert_not Oauth::ClientMetadata::FetchLease.enabled? }
    with_oauth_config(cimd_fetch_lease: nil, cimd_open_registration: true) { assert Oauth::ClientMetadata::FetchLease.enabled? }
    with_oauth_config(cimd_fetch_lease: "true", cimd_open_registration: true) { assert_not Oauth::ClientMetadata::FetchLease.enabled? }
    with_oauth_config(cimd_fetch_lease: true, cimd_open_registration: false) { assert Oauth::ClientMetadata::FetchLease.enabled? }
  end

  test "holds a slot while admitted, and releases it" do
    with_lease do
      events = lease_events do
        Oauth::ClientMetadata::FetchLease.admit do |admitted|
          assert admitted
          assert_not slot_free?(0)
        end
      end

      assert slot_free?(0)
      assert_equal [ [ "cimd_lease.oauth", { outcome: :admitted } ] ], events
    end
  end

  test "releases the slot when the block raises" do
    with_lease do
      assert_raises(RuntimeError) { Oauth::ClientMetadata::FetchLease.admit { raise "boom" } }

      assert slot_free?(0)
    end
  end

  test "a backend failure refuses" do
    Oauth::ClientMetadata::FetchLease::NamedLocks.stubs(:acquire).raises(ActiveRecord::ConnectionNotEstablished)
    Oauth::ClientMetadata::FetchLease::FileSlots.stubs(:acquire).raises(Errno::EACCES)

    with_lease do
      events = lease_events do
        Oauth::ClientMetadata::FetchLease.admit { |admitted| assert_not admitted }
      end

      assert_equal [ [ "cimd_lease_error.oauth", { operation: "acquire" } ], [ "cimd_lease.oauth", { outcome: :refused } ] ], events
    end
  end

  test "an engine with no backend refuses" do
    Oauth::ClientMetadata::FetchLease.stubs(:adapter).returns("postgresql")

    with_lease do
      Oauth::ClientMetadata::FetchLease.admit { |admitted| assert_not admitted }
    end
  end

  test "a failed release is reported, and doesn't replace the caller's outcome" do
    Oauth::ClientMetadata::FetchLease::NamedLocks::Lease.any_instance.stubs(:release).raises(ActiveRecord::ConnectionNotEstablished)
    Oauth::ClientMetadata::FetchLease::FileSlots::Lease.any_instance.stubs(:release).raises(IOError)

    with_lease do
      events = lease_events do
        assert_equal :fetched, Oauth::ClientMetadata::FetchLease.admit { :fetched }
      end

      assert_includes events, [ "cimd_lease_error.oauth", { operation: "release" } ]
    end
  end

  test "named locks are scoped to the environment and database, within MySQL's 64 characters" do
    connection = Oauth::Client.lease_connection
    connection.stubs(:current_database).returns("fizzy_" + "x" * 100)

    name = Oauth::ClientMetadata::FetchLease::NamedLocks.lock_name(connection, 5)

    assert_operator name.length, :<=, 64
    assert_match(/\Afizzy:cimd_fetch:test:\h{12}:5\z/, name)
    connection.stubs(:current_database).returns("fizzy_other")
    assert_not_equal name, Oauth::ClientMetadata::FetchLease::NamedLocks.lock_name(connection, 5)
  end

  test "slot files live beside a SQLite database" do
    Oauth::ClientMetadata::FetchLease.unstub(:slots_directory)
    connection = Oauth::Client.lease_connection

    if connection.adapter_name.match?(/sqlite/i)
      assert_equal Pathname.new(connection.raw_connection.filename).dirname.join("oauth_cimd_fetch_lease"), Oauth::ClientMetadata::FetchLease.slots_directory
    else
      assert_equal Rails.root.join("tmp", "oauth_cimd_fetch_lease"), Oauth::ClientMetadata::FetchLease.slots_directory
    end
  end
end

# Holders on connections of their own, as separate requests are: a test
# transaction would pin every thread to one connection.
class Oauth::ClientMetadata::FetchLeaseConcurrencyTest < ActiveSupport::TestCase
  include FetchLeaseTestHelper

  self.use_transactional_tests = false

  test "admits at most SLOTS at once, refuses the next without waiting, and admits again once one is released" do
    slots = Oauth::ClientMetadata::FetchLease::SLOTS
    held, gate = Queue.new, Queue.new

    with_lease do
      holders = slots.times.map do
        Thread.new do
          Oauth::ClientMetadata::FetchLease.admit do |admitted|
            held << admitted
            gate.pop
          end
        end
      end

      assert_equal [ true ] * slots, Array.new(slots) { held.pop }
      slots.times { |index| assert_not slot_free?(index) }

      refused_in = Benchmark.realtime do
        Thread.new { Oauth::ClientMetadata::FetchLease.admit { |admitted| assert_not admitted } }.join
      end
      assert_operator refused_in, :<, 1

      gate << :release
      sleep 0.01 until held.empty? && holders.count(&:alive?) < slots

      Thread.new { Oauth::ClientMetadata::FetchLease.admit { |admitted| assert admitted } }.join

      (slots - 1).times { gate << :release }
      holders.each(&:join)
    end

    slots.times { |index| assert slot_free?(index) }
  end
end
