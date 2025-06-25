module Searchable
  extend ActiveSupport::Concern

  included do
    has_one :search_embedding, as: :record, dependent: :destroy, class_name: "Search::Embedding"

    after_create_commit :refresh_search_embedding_later
    after_update_commit :refresh_search_embedding_later
    after_destroy_commit :remove_search_embedding
  end

  class_methods do
    def searchable_by(*fields, using:)
      define_method :search_fields do
        fields
      end

      define_method :search_values do
        fields.map do
          value = send(it)
          value.respond_to?(:to_plain_text) ? value.to_plain_text : value
        end
      end

      define_method :search_table do
        using
      end

      after_create_commit :create_in_search_index
      after_update_commit :update_in_search_index
      after_destroy_commit :remove_from_search_index

      scope :search, ->(query) do
        query = Search::Query.wrap(query)
        if query.valid?
          joins("join #{using} idx on #{table_name}.id = idx.rowid").where("#{using} match ?", query.to_s)
        else
          none
        end
      end

      scope :search_similar, ->(query) do
        query_embedding = Rails.cache.fetch("embed-search:#{query}") { RubyLLM.embed(Ai::Tokenizer.truncate(query)) }
        joins(:search_embedding)
          .where("embedding MATCH ? AND k = ?", query_embedding.vectors.to_json, 20)
          .order(:distance)
      end
    end
  end

  def reindex
    update_in_search_index
  end

  def refresh_search_embedding
    embedding = RubyLLM.embed(Ai::Tokenizer.truncate(search_embedding_content))
    search_embedding = self.search_embedding || build_search_embedding
    search_embedding.update! embedding: embedding.vectors.to_json
  end

  private
    def create_in_search_index
      fields_sql = [ "rowid", *search_fields ].join(", ")
      placeholders = ([ "?" ] * (search_fields.size + 1)).join(", ")
      values = [ id, *search_values ]

      execute_sql_with_binds(
        "insert into #{search_table}(#{fields_sql}) values (#{placeholders})",
        *values
      )
    end

    def update_in_search_index
      transaction do
        set_clause = search_fields.map { |field| "#{field} = ?" }.join(", ")
        binds = search_values + [ id ]

        updated = execute_sql_with_binds(
          "update #{search_table} set #{set_clause} where rowid = ?",
          *binds
        )

        create_in_search_index unless updated
      end
    end

    def remove_from_search_index
      execute_sql_with_binds "delete from #{search_table} where rowid = ?", id
    end

    def refresh_search_embedding_later
      Search::RefreshEmbeddingJob.perform_later(self)
    end

    def execute_sql_with_binds(*statement)
      self.class.connection.execute self.class.sanitize_sql(statement)
      self.class.connection.raw_connection.changes.nonzero?
    end

    def remove_search_embedding
      search_embedding&.destroy
    end
end
