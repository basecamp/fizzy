module Searchable
  extend ActiveSupport::Concern

  class_methods do
    def searchable_by(field, using:, as: field)
      define_method :search_value do send(field); end
      define_method :search_field do as; end
      define_method :search_table do using; end

      after_create_commit  :create_in_search_index
      after_update_commit  :update_in_search_index
      after_destroy_commit :remove_from_search_index

      scope :search, ->(query) { joins("join #{using} idx on #{table_name}.id = idx.rowid").where("idx.#{as} match ?", query) }
    end

    def reindex_all
      find_each(&:reindex)
    end
  end

  def reindex
    update_in_search_index
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
end
