require "test_helper"
require "yabeda/testing"

class Yabeda::SolidCacheTest < ActiveSupport::TestCase
  setup do
    Yabeda::TestAdapter.instance.reset!
  end

  test "sets gauges from cache stats and shard ages" do
    freeze_time do
      stub_solid_cache \
        connection_stats: { cache: { max_age: 100, oldest_age: 200, max_entries: 50, entries: 10 } },
        oldest_entry_created_at: 3.days.ago

      Yabeda::SolidCache.collect_stats

      assert_equal 100, gauge(:solid_cache_max_age_seconds)
      assert_equal 3.days.to_i, gauge(:solid_cache_oldest_age_seconds)
      assert_equal 10, gauge(:solid_cache_entries_total)
      assert_equal 50, gauge(:solid_cache_max_entries)
    end
  end

  test "is a no-op when not using the Solid Cache store" do
    Rails.stubs(:cache).returns(ActiveSupport::Cache::MemoryStore.new)

    Yabeda::SolidCache.collect_stats

    assert_nil gauge(:solid_cache_max_age_seconds)
  end

  test "swallows stats errors so a scrape never fails" do
    store = ::SolidCache::Store.allocate
    store.stubs(:stats).raises(StandardError.new("boom"))
    Rails.stubs(:cache).returns(store)
    ::SolidCache::Record.stubs(:each_shard)

    assert_nothing_raised { Yabeda::SolidCache.collect_stats }
    assert_nil gauge(:solid_cache_max_age_seconds)
  end

  private
    def stub_solid_cache(connection_stats:, oldest_entry_created_at:)
      store = ::SolidCache::Store.allocate
      store.stubs(:stats).returns(connection_stats: connection_stats)
      Rails.stubs(:cache).returns(store)

      ::SolidCache::Record.stubs(:each_shard).yields
      ::SolidCache::Record.stubs(:connection_db_config).returns(stub(name: "cache"))
      ::SolidCache::Entry.stubs(:order).returns(stub(first: stub(created_at: oldest_entry_created_at)))
    end

    def gauge(metric, shard: "cache")
      Yabeda::TestAdapter.instance.gauges[Yabeda.fizzy.public_send(metric)][{ shard: shard }]
    end
end
