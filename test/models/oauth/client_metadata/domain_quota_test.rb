require "test_helper"

class Oauth::ClientMetadata::DomainQuotaTest < ActiveSupport::TestCase
  DOMAIN = "example.com"
  CAP = Oauth::ClientMetadata::DomainQuota::CAP

  test "reserving charges the window up to the cap, then refuses" do
    CAP.times { assert reserve }

    assert_not reserve
    assert_equal CAP, quota.created_count
  end

  test "an expired window starts again rather than refusing for good" do
    Oauth::ClientMetadata::DomainQuota.create! registrable_domain: DOMAIN, window_started_at: 31.days.ago, created_count: CAP

    assert reserve
    assert_equal 1, quota.created_count
    assert quota.window_started_at > 1.minute.ago
  end

  test "exhausted only while the cap is spent and the window current" do
    assert_not Oauth::ClientMetadata::DomainQuota.exhausted?(DOMAIN)

    row = Oauth::ClientMetadata::DomainQuota.create! registrable_domain: DOMAIN, window_started_at: Time.current, created_count: CAP
    assert Oauth::ClientMetadata::DomainQuota.exhausted?(DOMAIN)

    row.update! window_started_at: 31.days.ago
    assert_not Oauth::ClientMetadata::DomainQuota.exhausted?(DOMAIN)

    row.update! window_started_at: Time.current, created_count: CAP - 1
    assert_not Oauth::ClientMetadata::DomainQuota.exhausted?(DOMAIN)
  end

  test "exhausted fails open when the read fails" do
    Oauth::ClientMetadata::DomainQuota.stubs(:find_by).raises(ActiveRecord::ConnectionNotEstablished)

    assert_not Oauth::ClientMetadata::DomainQuota.exhausted?(DOMAIN)
  end

  test "a rolled back transaction refunds its charge" do
    Oauth::ClientMetadata::DomainQuota.transaction(requires_new: true) do
      assert Oauth::ClientMetadata::DomainQuota.acquire(DOMAIN).reserve
      raise ActiveRecord::Rollback
    end

    assert_equal 0, Oauth::ClientMetadata::DomainQuota.where(registrable_domain: DOMAIN).sum(:created_count)
  end

  test "acquiring an existing row reuses it" do
    reserve

    assert_equal quota, Oauth::ClientMetadata::DomainQuota.transaction { Oauth::ClientMetadata::DomainQuota.acquire(DOMAIN) }
    assert_equal 1, Oauth::ClientMetadata::DomainQuota.where(registrable_domain: DOMAIN).count
  end

  test "losing the race to create a row reads the winner's" do
    winner = Oauth::ClientMetadata::DomainQuota.create! registrable_domain: DOMAIN, window_started_at: Time.current, created_count: 3
    finds = sequence("finds")
    Oauth::ClientMetadata::DomainQuota.expects(:lock).returns(Oauth::ClientMetadata::DomainQuota.none).in_sequence(finds)
    Oauth::ClientMetadata::DomainQuota.expects(:lock).returns(Oauth::ClientMetadata::DomainQuota.all).in_sequence(finds)

    assert_equal winner, Oauth::ClientMetadata::DomainQuota.transaction { Oauth::ClientMetadata::DomainQuota.acquire(DOMAIN) }
  end

  test "cleanup deletes only rows whose window has elapsed" do
    expired = Oauth::ClientMetadata::DomainQuota.create! registrable_domain: "expired.example.com", window_started_at: 31.days.ago, created_count: CAP
    current = Oauth::ClientMetadata::DomainQuota.create! registrable_domain: "current.example.com", window_started_at: 29.days.ago, created_count: 1
    spent = Oauth::ClientMetadata::DomainQuota.create! registrable_domain: DOMAIN, window_started_at: Time.current, created_count: CAP

    Oauth::ClientMetadata::DomainQuota.cleanup

    assert_not Oauth::ClientMetadata::DomainQuota.exists?(expired.id)
    assert Oauth::ClientMetadata::DomainQuota.exists?(current.id)
    assert Oauth::ClientMetadata::DomainQuota.exists?(spent.id)
    assert Oauth::ClientMetadata::DomainQuota.exhausted?(DOMAIN)
  end

  private
    def reserve
      Oauth::ClientMetadata::DomainQuota.transaction { Oauth::ClientMetadata::DomainQuota.acquire(DOMAIN).reserve }
    end

    def quota
      Oauth::ClientMetadata::DomainQuota.find_by!(registrable_domain: DOMAIN)
    end
end

# The race a cache counter loses: concurrent first reservations for a domain
# with no row yet admit exactly the cap. Real connections on the real engine.
class Oauth::ClientMetadata::DomainQuotaConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  DOMAIN = "cold.example.com"

  setup { Oauth::ClientMetadata::DomainQuota.where(registrable_domain: DOMAIN).delete_all }
  teardown { Oauth::ClientMetadata::DomainQuota.where(registrable_domain: DOMAIN).delete_all }

  # A deadlock would raise out of its thread's join and fail the test: with
  # the row committed first, there's none to answer, on either isolation level.
  test "concurrent reservations on a cold domain admit exactly the cap, without deadlocking" do
    workers, attempts_each = 8, 5
    assert_operator workers * attempts_each, :>, Oauth::ClientMetadata::DomainQuota::CAP

    results = Queue.new
    workers.times.map do
      Thread.new do
        Oauth::ClientMetadata::DomainQuota.with_connection do
          attempts_each.times do
            Oauth::ClientMetadata::DomainQuota.prepare(DOMAIN)
            results << Oauth::ClientMetadata::DomainQuota.transaction { Oauth::ClientMetadata::DomainQuota.acquire(DOMAIN).reserve }
          end
        end
      end
    end.each(&:join)

    outcomes = Array.new(workers * attempts_each) { results.pop }
    assert_equal Oauth::ClientMetadata::DomainQuota::CAP, outcomes.count(true)
    assert_equal workers * attempts_each - Oauth::ClientMetadata::DomainQuota::CAP, outcomes.count(false)
    assert_equal Oauth::ClientMetadata::DomainQuota::CAP, Oauth::ClientMetadata::DomainQuota.find_by!(registrable_domain: DOMAIN).created_count
  end
end
