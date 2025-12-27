# Automatically use UUID type for all binary(16) columns and generate defaults

module UuidPrimaryKeyDefault
  def load_schema!
    define_uuid_primary_key_pending_default
    super
  end

  private
    def define_uuid_primary_key_pending_default
      if uuid_primary_key?
        pending_attribute_modifications << PendingUuidDefault.new(primary_key)
      end
    rescue ActiveRecord::StatementInvalid
      # Table doesn't exist yet
    end

    def uuid_primary_key?
      table_name && primary_key && schema_cache.columns_hash(table_name)[primary_key]&.type == :uuid
    end

    PendingUuidDefault = Struct.new(:name) do
      def apply_to(attribute_set)
        attribute_set[name] = attribute_set[name].with_user_default(-> { ActiveRecord::Type::Uuid.generate })
      end
    end
end

module MysqlUuidAdapter
  extend ActiveSupport::Concern

  # Override lookup_cast_type to recognize binary(16) as UUID type
  def lookup_cast_type(sql_type)
    if sql_type == "binary(16)"
      ActiveRecord::Type.lookup(:uuid, adapter: :trilogy)
    else
      super
    end
  end

  # Override fetch_type_metadata to preserve UUID type and limit
  def fetch_type_metadata(sql_type, extra = "")
    if sql_type == "binary(16)"
      simple_type = ActiveRecord::ConnectionAdapters::SqlTypeMetadata.new(
        sql_type: sql_type,
        type: :uuid,
        limit: 16
      )
      ActiveRecord::ConnectionAdapters::MySQL::TypeMetadata.new(simple_type, extra: extra)
    else
      super
    end
  end

  class_methods do
    def native_database_types
      @native_database_types_with_uuid ||= super.merge(uuid: { name: "binary", limit: 16 })
    end
  end
end

module SqliteUuidAdapter
  extend ActiveSupport::Concern

  # Override lookup_cast_type to recognize BLOB as UUID type
  def lookup_cast_type(sql_type)
    if sql_type == "blob(16)"
      ActiveRecord::Type.lookup(:uuid, adapter: :sqlite3)
    else
      super
    end
  end

  # Override fetch_type_metadata to preserve UUID type and limit
  def fetch_type_metadata(sql_type)
    if sql_type == "blob(16)"
      ActiveRecord::ConnectionAdapters::SqlTypeMetadata.new(
        sql_type: sql_type,
        type: :uuid,
        limit: 16
      )
    else
      super
    end
  end

  class_methods do
    def native_database_types
      @native_database_types_with_uuid ||= super.merge(uuid: { name: "blob", limit: 16 })
    end
  end
end

module SchemaDumperUuidType
  # Map binary(16) and blob(16) columns to :uuid type in schema.rb
  def schema_type(column)
    if column.sql_type == "binary(16)" || column.sql_type == "blob(16)"
      :uuid
    else
      super
    end
  end
end

module TableDefinitionUuidSupport
  def uuid(name, **options)
    column(name, :uuid, **options)
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Base.singleton_class.prepend(UuidPrimaryKeyDefault)
  ActiveRecord::ConnectionAdapters::TableDefinition.prepend(TableDefinitionUuidSupport)
end

ActiveSupport.on_load(:active_record_trilogyadapter) do
  ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter.prepend(MysqlUuidAdapter)
  ActiveRecord::ConnectionAdapters::MySQL::SchemaDumper.prepend(SchemaDumperUuidType)
end

ActiveSupport.on_load(:active_record_sqlite3adapter) do
  ActiveRecord::ConnectionAdapters::SQLite3Adapter.prepend(SqliteUuidAdapter)
  ActiveRecord::ConnectionAdapters::SQLite3::SchemaDumper.prepend(SchemaDumperUuidType)
end
