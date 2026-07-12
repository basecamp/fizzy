# frozen_string_literal: true

# Query optimizer hints for ActiveRecord
#
# Provides methods to pass optimizer hints to the database query planner.
# Uses MySQL 8 optimizer hint query comments. Other databases (MariaDB, SQLite, etc.)
# ignore these comments, making this a safe no-op across all databases.
#
# Documentation:
#   * https://dev.mysql.com/doc/refman/8.0/en/optimizer-hints.html
#
# Examples:
#   Card.use_index(:index_cards_on_account_id_and_board_id_and_status).where(...)
#   Event.joins(:recording).join_prefix(:events)

module ActiveRecordBaseOptimizerHintExtensions
  # Pass index hints to the query optimizer
  #
  # @param indexes [Array<Symbol>] Index names to use
  # @return [ActiveRecord::Relation]
  # @example
  #   Card.use_index(:index_cards_on_account_id_and_board_id_and_status).where(...)
  def use_index(*indexes)
    all.use_index(*indexes)
  end

  # Override the default join order
  #
  # @param table [String, Symbol] Table name to join first
  # @return [ActiveRecord::Relation]
  # @example
  #   Event.joins(:recording).join_prefix(:events)
  def join_prefix(table)
    all.join_prefix(table)
  end
end

module ActiveRecordRelationOptimizerHintExtensions
  # Pass index hints to the query optimizer using SQL comment hints.
  # Uses MySQL 8 optimizer hint query comments. Other databases (MariaDB, SQLite, etc.)
  # ignore these comments, making this a safe no-op across all databases.
  #
  # Documentation:
  #   * https://dev.mysql.com/doc/refman/8.0/en/optimizer-hints.html
  #
  # Example:
  #   Card.use_index(:index_cards_on_account_id_and_board_id_and_status)
  #
  #   => Card Load (0.5ms)  SELECT /*+ INDEX(`cards` index_cards_on_account_id_and_board_id_and_status) */ `cards`.*
  #      FROM `cards` WHERE ...
  #
  # Multiple indexes:
  #   Card.use_index(:index_a, :index_b)
  #
  #   => Card Load (0.5ms)  SELECT /*+ INDEX(`cards` index_a, index_b) */ `cards`.* FROM `cards`
  #
  # Calling use_index again replaces a previously hinted index for the same table, so the most
  # specific scope wins. MySQL only honors the first INDEX hint per table and silently ignores
  # the rest, so appending a second hint would have no effect:
  #   Card.use_index(:index_a).use_index(:index_b)
  #
  #   => Card Load (0.5ms)  SELECT /*+ INDEX(`cards` index_b) */ `cards`.* FROM `cards`
  def use_index(*indexes)
    kept_hints = optimizer_hints_values.reject { |hint| hint.to_s.start_with?("INDEX(#{quoted_table_name} ") }
    except(:optimizer_hints).optimizer_hints(*kept_hints, "INDEX(#{quoted_table_name} #{indexes.join(', ')})")
  end

  # Optimizer hint to override the default join order.
  # Uses MySQL 8 optimizer hints. Other databases ignore these hints.
  #
  # Documentation:
  #    https://dev.mysql.com/doc/refman/8.0/en/optimizer-hints.html#optimizer-hints-join-order
  #
  # Example:
  #   Event.joins(:recording).join_prefix(:events)
  #
  #   => Event Load (0.9ms)  SELECT /*+ JOIN_PREFIX(`events`) */ `events`.* FROM `events`
  #      INNER JOIN `recordings` ON `recordings`.`id` = `events`.`recording_id`
  #
  def join_prefix(table)
    optimizer_hints "JOIN_PREFIX(#{connection.quote_table_name(table)})"
  end
end

ActiveRecord::Base.singleton_class.prepend(ActiveRecordBaseOptimizerHintExtensions)
ActiveRecord::Relation.prepend(ActiveRecordRelationOptimizerHintExtensions)
