module Searchable
  extend ActiveSupport::Concern

  included do
    has_one :search_embedding, as: :record, dependent: :destroy, class_name: "Search::Embedding"

    after_create_commit  :refresh_search_embedding
    after_update_commit  :refresh_search_embedding
    after_destroy_commit :remove_search_embedding
  end

  class_methods do
    def searchable_by(field, using:, as: field)
      define_method :search_value do send(field); end
      define_method :search_field do as; end
      define_method :search_table do using; end

      after_create_commit  :create_in_search_index
      after_update_commit  :update_in_search_index
      after_destroy_commit :remove_from_search_index

      scope :search, ->(query) { joins("join #{using} idx on #{table_name}.id = idx.rowid").where("idx.#{as} match ?", query) }
      scope :search_similar, ->(query) do
        query_embedding = RubyLLM.embed(query)
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
    embedding = RubyLLM.embed(search_embedding_content)
    search_embedding = self.search_embedding || build_search_embedding
    search_embedding.update! embedding: embedding.vectors.to_json
  end

  private
    def create_in_search_index
      execute_sql_with_binds "insert into #{search_table}(rowid, #{search_field}) values (?, ?)", id, search_value
    end

    def update_in_search_index
      transaction do
        updated = execute_sql_with_binds "update #{search_table} set #{search_field} = ? where rowid = ?", search_value, id
        create_in_search_index unless updated
      end
    end

    def remove_from_search_index
      execute_sql_with_binds "delete from #{search_table} where rowid = ?", id
    end

    def execute_sql_with_binds(*statement)
      self.class.connection.execute self.class.sanitize_sql(statement)
      self.class.connection.raw_connection.changes.nonzero?
    end

    def remove_search_embedding
      search_embedding&.destroy
    end
end
