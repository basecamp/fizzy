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

  ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter.prepend(MysqlUuidAdapter)

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

  ActiveRecord::ConnectionAdapters::MySQL::SchemaDumper.prepend(SchemaDumperUuidType)

  module TableDefinitionUuidSupport
    def uuid(name, **options)
      column(name, :uuid, **options)
    end
  end

  ActiveRecord::ConnectionAdapters::TableDefinition.prepend(TableDefinitionUuidSupport)
end
