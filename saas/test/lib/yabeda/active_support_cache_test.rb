require "test_helper"
require "yabeda/testing"

class Yabeda::ActiveSupportCacheTest < ActiveSupport::TestCase
  setup do
    Yabeda::TestAdapter.instance.reset!
  end

  test "counts operations" do
    with_caching_enabled do
      Rails.cache.write("entry1", 1)

      assert_equal 1, count(:cache_operations_total, operation: "write")
      assert_operator count(:cache_operations_seconds_total, operation: "write"), :>, 0
    end
  end

  test "counts hits from read" do
    with_caching_enabled do
      Rails.cache.write("entry1", 1)
      Rails.cache.read("entry1")
      Rails.cache.read("entry2")
      Rails.cache.read("entry3")

      assert_equal 1, count(:cache_hits_total, operation: "read")
      assert_equal 3, count(:cache_requests_total, operation: "read")
    end
  end

  test "counts hits from read_multi" do
    with_caching_enabled do
      Rails.cache.write("entry1", 1)
      Rails.cache.write("entry3", 3)
      Rails.cache.read_multi("entry1", "entry2", "entry3")

      assert_equal 2, count(:cache_hits_total, operation: "read_multi")
      assert_equal 3, count(:cache_requests_total, operation: "read_multi")
    end
  end

  private
    def with_caching_enabled
      old_cache = Rails.cache
      Rails.cache = ActiveSupport::Cache.lookup_store(:memory_store)
      yield
    ensure
      Rails.cache = old_cache
    end

    def count(metric, operation:)
      tags = { store: "ActiveSupport::Cache::MemoryStore", operation: operation }
      Yabeda::TestAdapter.instance.counters.fetch(Yabeda.active_support.public_send(metric))[tags]
    end
end
