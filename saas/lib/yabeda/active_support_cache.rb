module Yabeda
  module ActiveSupportCache
    def self.install!
      Yabeda.configure do
        tag_names = %i[ store operation ]

        group :active_support

        counter :cache_requests_total, comment: "Active Support cache requests", tags: tag_names
        counter :cache_hits_total, comment: "Active Support cache hits", tags: tag_names
        counter :cache_operations_total, comment: "Count of Active Support cache operations", tags: tag_names
        counter :cache_operations_seconds_total, comment: "Seconds spent on Active Support cache operations", tags: tag_names

        ActiveSupport::Notifications.monotonic_subscribe /cache_[a-z_]+\.active_support/ do |name, start, finish, id, payload|
          store = payload[:store]
          next if store == "ActiveSupport::Cache::FileStore" # sprockets

          operation = name.match(/^cache_([^.]*)/)[1]
          tags = { store: store, operation: operation }
          requests, hits = ActiveSupportCache.requests_and_hits(operation, payload)

          next if operation == "read_multi" && requests == 0 # no-op

          active_support_cache_requests_total.increment(tags, by: requests) if requests > 0
          active_support_cache_hits_total.increment(tags, by: hits) if hits > 0
          active_support_cache_operations_total.increment(tags)
          active_support_cache_operations_seconds_total.increment(tags, by: finish - start)
        end
      end
    end

    private
      def self.requests_and_hits(operation, payload)
        case operation
        when "read"
          [ 1, payload[:hit] ? 1 : 0 ]
        when "read_multi"
          [ payload[:key]&.count || 0, payload[:hits]&.count || 0 ]
        else
          [ 0, 0 ]
        end
      end
  end
end
