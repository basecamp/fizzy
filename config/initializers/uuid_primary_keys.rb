# Automatically use UUID type for all binary(16) columns
ActiveSupport.on_load(:active_record) do
  module MysqlUuidAdapter
    # Add UUID to MySQL's native database types
    def native_database_types
      @native_database_types_with_uuid ||= super.merge(uuid: { name: "binary", limit: 16 })
    end

    # Override lookup_cast_type to recognize binary(16) as UUID type
    def lookup_cast_type(sql_type)
      if sql_type == "binary(16)"
        ActiveRecord::Type.lookup(:uuid, adapter: :trilogy)
      else
        super
      end
    end
  end

  if defined?(ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter)
    ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter.prepend(MysqlUuidAdapter)
  end

  module SqliteUuidAdapter
    # Add UUID to SQLite's native database types
    def native_database_types
      @native_database_types_with_uuid ||= super.merge(uuid: { name: "blob", limit: 16 })
    end

    # Override lookup_cast_type to recognize BLOB as UUID type
    def lookup_cast_type(sql_type)
      if sql_type == "BLOB" || sql_type == "blob(16)"
        ActiveRecord::Type.lookup(:uuid, adapter: :sqlite3)
      else
        super
      end
    end
  end

  if defined?(ActiveRecord::ConnectionAdapters::SQLite3Adapter)
    ActiveRecord::ConnectionAdapters::SQLite3Adapter.prepend(SqliteUuidAdapter)
  end

  module SchemaDumperUuidType
    # Map binary(16) columns to :uuid type in schema.rb
    def schema_type(column)
      if column.sql_type == "binary(16)"
        :uuid
      else
        super
      end
    end
  end

  if defined?(ActiveRecord::ConnectionAdapters::MySQL::SchemaDumper)
    ActiveRecord::ConnectionAdapters::MySQL::SchemaDumper.prepend(SchemaDumperUuidType)
  end

  module TableDefinitionUuidSupport
    def uuid(name, **options)
      column(name, :uuid, **options)
    end
  end

  ActiveRecord::ConnectionAdapters::TableDefinition.prepend(TableDefinitionUuidSupport)
end
