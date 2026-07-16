module Yabeda
  module SolidCache
    SECONDS_PER_DAY = 86_400
    DEFAULT_METRIC_VALUE = 0

    def self.install!
      Yabeda.configure do
        group :fizzy

        gauge :solid_cache_max_age_seconds, comment: "Solid Cache max age in seconds", tags: %i[ shard ], aggregation: :most_recent
        gauge :solid_cache_oldest_age_seconds, comment: "Solid Cache oldest entry age in seconds", tags: %i[ shard ], aggregation: :most_recent
        gauge :solid_cache_max_entries, comment: "Solid Cache max entries", tags: %i[ shard ], aggregation: :most_recent
        gauge :solid_cache_entries_total, comment: "Solid Cache entries", tags: %i[ shard ], aggregation: :most_recent

        collect do
          Yabeda::SolidCache.collect_stats if defined?(::SolidCache::Entry)
        end
      end
    end

    def self.collect_stats
      return unless ::Rails.cache.is_a?(::SolidCache::Store)

      enrichment = enrichment_from_cache_stats
      ages = oldest_ages_per_shard

      (enrichment.keys + ages.keys).uniq.each do |shard|
        set_shard_metrics(shard, enrichment[shard], ages[shard])
      end
    rescue => error
      ::Rails.logger.warn "Failed to collect Solid Cache stats: #{error.message}"
    end

    private
      # Active shards contribute enrichment data via ::Rails.cache.stats; every shard
      # (including inactive ones) contributes an oldest-entry age via each_shard. We
      # set whatever metrics we have for each shard we find in either source.
      def self.set_shard_metrics(shard, enrichment, age_days)
        if enrichment && age_days
          set_metrics shard,
            max_age: enrichment[:max_age],
            oldest_age: (age_days * SECONDS_PER_DAY).to_i,
            entries: enrichment[:entries],
            max_entries: enrichment[:max_entries]
        elsif enrichment
          set_metrics shard,
            max_age: enrichment[:max_age],
            oldest_age: enrichment[:oldest_age],
            entries: enrichment[:entries],
            max_entries: enrichment[:max_entries]
        elsif age_days
          oldest_age = (age_days * SECONDS_PER_DAY).to_i
          set_metrics shard,
            max_age: oldest_age,
            oldest_age: oldest_age,
            entries: DEFAULT_METRIC_VALUE,
            max_entries: DEFAULT_METRIC_VALUE
        end
      rescue => error
        ::Rails.logger.warn "Failed to collect Solid Cache stats for shard #{shard}: #{error.message}"
      end

      def self.set_metrics(shard, max_age:, oldest_age:, entries:, max_entries:)
        tags = { shard: shard }
        Yabeda.fizzy.solid_cache_max_age_seconds.set(tags, max_age)
        Yabeda.fizzy.solid_cache_oldest_age_seconds.set(tags, oldest_age)
        Yabeda.fizzy.solid_cache_entries_total.set(tags, entries)
        Yabeda.fizzy.solid_cache_max_entries.set(tags, max_entries)
      end

      def self.enrichment_from_cache_stats
        connection_stats = ::Rails.cache.stats&.dig(:connection_stats)
        return {} unless connection_stats

        connection_stats.each_with_object({}) do |(shard, stats), enrichment|
          enrichment[shard.to_s] = normalize_shard_stats(stats) if stats
        end
      rescue => error
        ::Rails.logger.warn "Failed to read Solid Cache stats: #{error.message}"
        {}
      end

      def self.oldest_ages_per_shard
        return {} unless ::SolidCache::Record.respond_to?(:each_shard)

        {}.tap do |ages|
          ::SolidCache::Record.each_shard do
            shard = ::SolidCache::Record.connection_db_config.name
            if age_days = oldest_entry_age_in_days
              ages[shard] = age_days
            end
          rescue => error
            ::Rails.logger.warn "Failed to read Solid Cache age for a shard: #{error.message}"
          end
        end
      rescue => error
        ::Rails.logger.warn "Failed to read Solid Cache shard ages: #{error.message}"
        {}
      end

      def self.oldest_entry_age_in_days
        if oldest_entry = ::SolidCache::Entry.order(:id).first
          (Time.current - oldest_entry.created_at) / SECONDS_PER_DAY
        end
      end

      def self.normalize_shard_stats(stats)
        {
          max_age: stats[:max_age]&.to_i || DEFAULT_METRIC_VALUE,
          oldest_age: stats[:oldest_age]&.to_i || DEFAULT_METRIC_VALUE,
          max_entries: stats[:max_entries]&.to_i || DEFAULT_METRIC_VALUE,
          entries: stats[:entries]&.to_i || DEFAULT_METRIC_VALUE
        }
      end
  end
end
