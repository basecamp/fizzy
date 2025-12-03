# Apply MySQL-compatible column limits when defining tables.
#
# For string columns: defaults to 255 (MySQL's VARCHAR default)
#
# For text columns: converts MySQL's `size:` option to equivalent limits:
#   - (blank/default): 65,535 (TEXT)
#   - size: :tiny: 255 (TINYTEXT)
#   - size: :medium: 16,777,215 (MEDIUMTEXT)
#   - size: :long: 4,294,967,295 (LONGTEXT)
#

module TableDefinitionColumnLimits
  TEXT_SIZE_TO_LIMIT = {
    tiny: 255,
    medium: 16_777_215,
    long: 4_294_967_295
  }.freeze

  TEXT_DEFAULT_LIMIT = 65_535
  STRING_DEFAULT_LIMIT = 255

  def column(name, type, **options)
    if type == :string
      options[:limit] ||= STRING_DEFAULT_LIMIT
    end

    if type == :text || type == :binary
      if options.key?(:size)
        size = options.delete(:size)
        options[:limit] ||= TEXT_SIZE_TO_LIMIT.fetch(size) do
          raise ArgumentError, "Unknown text size: #{size.inspect}. Use :tiny, :medium, or :long"
        end
      elsif type == :text
        options[:limit] ||= TEXT_DEFAULT_LIMIT
      end
    end

    super
  end
end

# For SQLite: append inline CHECK constraints to enforce string/text length limits.
# since SQLite doesn't natively enforce VARCHAR/TEXT length limits.
module SQLiteColumnLimitCheckConstraints
  def add_column_options!(sql, options)
    super

    column = options[:column]
    if column && column.limit && %i[string text].include?(column.type)
      check_expr = if column.type == :string
        # VARCHAR limits are in characters
        %(length("#{column.name}") <= #{column.limit})
      else
        # TEXT limits are in bytes
        %(length(CAST("#{column.name}" AS BLOB)) <= #{column.limit})
      end
      sql << " CHECK(#{check_expr})"
    end

    sql
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::ConnectionAdapters::TableDefinition.prepend(TableDefinitionColumnLimits)
end

ActiveSupport.on_load(:active_record_sqlite3adapter) do
  ActiveRecord::ConnectionAdapters::SQLite3::SchemaCreation.prepend(SQLiteColumnLimitCheckConstraints)
end
