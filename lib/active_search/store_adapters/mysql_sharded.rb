require "zlib"

module ActiveSearch
  module StoreAdapters
    class MysqlSharded < Mysql
      SHARD_COUNT = 16

      include SourceHighlighting, Stemming, Highlighting

      # Absent fields are written as NULL: upsert leaves columns it is not given untouched.
      def write(index, document, routing: nil)
        model = model_for_shard(routing)
        data = stem_document_data(document)
        cleared = document.absent_fields.index_with(nil)
        attributes = index.source.storage_key(document.id).merge(cleared, data)
        attributes[:id] ||= ActiveRecord::Type::Uuid.generate
        update_columns = (data.keys + document.absent_fields).map(&:to_s)

        model.upsert(attributes, on_duplicate: Arel.sql(update_columns.map { |c| "#{c} = VALUES(#{c})" }.join(", ")))
      end

      # Capabilities does not inherit, so anything Mysql sets and we omit here silently
      # reverts to the gem's default. MysqlShardedTest holds this list against Mysql's.
      def capabilities
        @capabilities ||= Capabilities.new(
          index_creation: true,
          highlighting: true,
          highlight_snippet_units: [ :words ],
          highlight_per_field_markers: false,
          highlight_per_field_snippets: true,
          operator: false,
          max_result_window: options.fetch(:max_result_window, 10_000)
        )
      end

      private
        # Must match the FULLTEXT index exactly, or MATCH raises.
        FULLTEXT_COLUMNS = %w[account_key content title].freeze

        # routing needs nothing here: build_raw_query has already stemmed it into the MATCH.
        def apply_search(model, query_context, index, routing:)
          connection = model.connection
          table = connection.quote_table_name(model.table_name)
          escaped = connection.quote(query_context.query.to_s)
          match_cols = FULLTEXT_COLUMNS.map { |c| "#{table}.#{connection.quote_column_name(c)}" }.join(", ")
          match_expr = "MATCH(#{match_cols}) AGAINST(#{escaped} IN BOOLEAN MODE)"

          model
            .select(Arel.sql(id_select_sql(model, index)), "#{match_expr} AS score")
            .where(Arel.sql(match_expr))
        end

        # The +account<id> token narrows the full-text scan to one account inside the index,
        # rather than matching the whole shard and discarding after. Isolation is the account_id
        # filter's job, not this token's.
        def build_raw_query(index, query_context, routing:)
          super(index, stem_query_context(query_context, routing), routing: routing)
        end

        def model_for(index, routing: nil)
          model_for_shard(routing)
        end

        # Index-wide work spans all sixteen shards, which inherit this class and its pool.
        def connection_model_for(index)
          Search::Record
        end

        # A name rather than the model: the observation cache keys by this and outlives
        # the anonymous shard classes.
        def schema_domain(index, routing)
          model_for_shard(routing).table_name
        end

        def observe_for(index, domain)
          connection = connection_model_for(index).connection
          raise ActiveRecord::StatementInvalid, "#{domain} does not exist" unless index_present?(domain, connection)

          observe_tables(index, domain, connection)
        end

        def model_for_shard(routing)
          raise ArgumentError, "routing (account_id) required for sharded adapter" unless routing
          shard_id = Zlib.crc32(routing.to_s) % SHARD_COUNT
          shard_models[shard_id]
        end

        # Must keep Search::Record's connection pool: Account::Searchable deletes by filter
        # from before_destroy, and a separate pool would deadlock on the destroy's own rows.
        def shard_models
          @shard_models ||= SHARD_COUNT.times.map do |shard_id|
            Class.new(Search::Record) { self.table_name = "search_records_#{shard_id}" }
          end
        end
    end
  end
end
