require "test_helper"

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

  test "failing to get a connection refuses, as a failed acquire does" do
    Oauth::ClientMetadata::FetchLease.stubs(:mysql?).returns(true)
    Oauth::Client.stubs(:with_connection).raises(ActiveRecord::ConnectionTimeoutError)

    with_lease do
      events = lease_events do
        assert_equal :refused, Oauth::ClientMetadata::FetchLease.admit { |admitted| admitted ? :admitted : :refused }
      end

      assert_equal [ [ "cimd_lease_error.oauth", { operation: "acquire" } ], [ "cimd_lease.oauth", { outcome: :refused } ] ], events
    end
  ensure
    Oauth::Client.unstub(:with_connection)
  end

  test "what the block raises on a held connection goes through, yielded once" do
    Oauth::ClientMetadata::FetchLease.stubs(:mysql?).returns(true)
    calls = 0

    with_lease do
      assert_raises(RuntimeError) do
        Oauth::ClientMetadata::FetchLease.admit { calls += 1; raise "boom" }
      end
    end

    assert_equal 1, calls
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
