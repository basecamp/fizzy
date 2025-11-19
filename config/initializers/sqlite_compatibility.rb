# SQLite compatibility layer - filters out MySQL-specific options when using SQLite

# Define modules outside on_load so they're available immediately
module SQLiteCompatibility
  module SQLiteTableDefinitionCompatibility
    # Override column method to filter out MySQL-specific options
    def column(name, type, **options)
      # Check if we're using SQLite by checking the connection adapter
      if @conn.is_a?(ActiveRecord::ConnectionAdapters::SQLite3Adapter)
        # Remove MySQL-specific options that SQLite doesn't support
        options = options.except(:size, :charset, :collation, :unsigned)
      end
      super(name, type, **options)
    end

    # Override index method to filter out MySQL-specific index options
    def index(column_name, **options)
      if @conn.is_a?(ActiveRecord::ConnectionAdapters::SQLite3Adapter)
        # Skip fulltext indexes entirely for SQLite
        return if options[:type] == :fulltext
        # SQLite doesn't support length-limited indexes
        options = options.except(:length)
      end
      super(column_name, **options)
    end
  end

  module SQLiteSchemaStatementCompatibility
    # Override create_table to filter out MySQL-specific table options
    def create_table(table_name, **options)
      if is_a?(ActiveRecord::ConnectionAdapters::SQLite3Adapter)
        # Remove MySQL-specific table options
        options = options.except(:charset, :collation)
      end
      super(table_name, **options)
    end
  end
end

# Apply the prepends - both in on_load callback and immediately
def apply_sqlite_compatibility
  if defined?(ActiveRecord::ConnectionAdapters::SQLite3Adapter)
    ActiveRecord::ConnectionAdapters::TableDefinition.prepend(SQLiteCompatibility::SQLiteTableDefinitionCompatibility)
    ActiveRecord::ConnectionAdapters::SQLite3Adapter.prepend(SQLiteCompatibility::SQLiteSchemaStatementCompatibility)
  end
end

# Run immediately if ActiveRecord is already loaded
apply_sqlite_compatibility

# Also run when ActiveRecord loads (for cases where it loads later)
ActiveSupport.on_load(:active_record) do
  apply_sqlite_compatibility
end
