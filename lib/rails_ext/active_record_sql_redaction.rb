# Trilogy runs without prepared statements, so a value reaches the SQL text as a quoted literal. The
# sql.active_record notification carries that text to every consumer, and with Rails.event in debug mode
# (config/application.rb) it reaches the log: in SaaS mode, the structured log line for the request or
# job, and from there Loki. Sentry breadcrumbs and spans read it too, and a database error can quote a
# value in its message. SQLite runs with prepared statements and logs the value as a bind,
# except in bulk inserts, which inline it.
#
# For the tables listed here every literal and every bind is secret enough to drop:
#
#   account_join_codes.code         joins whoever holds it to the account
#   identity_access_tokens.token    API bearer token
#   identity_transfers.token        signs its holder in as the identity
#   magic_links.code                signs its holder in as the identity
#   webhooks.signing_secret, .url   signs payloads; a chat webhook URL is itself a credential
#
# Filtering by table rather than column keeps INSERT ... VALUES, multi-row inserts and IN lists covered
# without parsing column positions. The statement sent to the database is never changed: only what is
# logged, reported or raised about it.
#
# A new column named like a credential (token, code, secret, key, ...) on another table fails
# test/lib/rails_ext/active_record_sql_redaction_test.rb until its table is listed here or the column is
# declared not secret there. A credential in a column named otherwise has to be listed by hand.
module ActiveRecordSqlRedaction
  TABLES = %w[ account_join_codes identity_access_tokens identity_transfers magic_links webhooks ].freeze

  # Names a table however the statement spells it: `magic_links` on MySQL, "magic_links" on SQLite, or bare
  # in hand-written SQL, in any case. Over-matching only filters more.
  TABLE = /\b(?:#{TABLES.map { |table| Regexp.escape(table) }.join("|")})\b/i

  # Everything from the first quote on, so every literal goes however the adapter escapes quotes inside
  # one (MySQL with a backslash, SQLite by doubling, where a value ending in a backslash would make a
  # literal-by-literal match end early), and a malformed statement whose last literal never closed loses
  # it too. What's left before the first quote is the statement's shape: its table, columns and the
  # condition the first value is compared in.
  LITERALS = /'.*/m

  FILTERED = "[FILTERED]"
  FILTERED_LITERAL = "'#{FILTERED}'"
  FILTERED_ERROR = "[FILTERED: a statement on a redacted table failed]"

  # A failed CREATE TABLE (1005) quotes no row, and Active Record reads its "errno: 150" to tell a
  # mismatched foreign key, so its message is kept.
  UNFILTERED_ERROR_CODES = [ 1005 ].freeze

  class << self
    def redact(sql)
      if redacted_statement?(sql)
        sql.sub(LITERALS, FILTERED_LITERAL)
      else
        sql
      end
    end

    def redacted_statement?(sql)
      sql.is_a?(String) && sql.match?(TABLE)
    end

    # Names a redacted table the way SQL and MySQL errors do: a quoted identifier in a statement, or the
    # key a duplicate entry collided on (MySQL 8 writes magic_links.index_magic_links_on_code, older
    # servers index_magic_links_on_code). Not a bare word or a path, so a route error for /my/webhooks
    # keeps its message.
    def mentions_redacted_table?(text)
      text.is_a?(String) && TABLES.any? { |table| text.match?(reference_to(table)) }
    end

    # A MySQL server error on such a statement can quote the row's values (a duplicate-entry error quotes
    # the entry), and nothing about its wording is safe to parse, so the whole message is replaced by its
    # code. Any other error is redacted like a statement: SQLite's syntax errors and Active
    # Record's read-only error quote the whole statement, while the wording the adapters classify errors by
    # (a UNIQUE constraint, a lost connection) quotes nothing and survives. Every sink that reads the error
    # afterwards, the translated Active Record error and its cause alike, sees the filtered message.
    def filter_error(error)
      filtered = \
        if server_error_code(error)
          [ error.error_code, FILTERED_ERROR ].join(": ")
        else
          redact_error_message(error.message)
        end

      error.define_singleton_method(:message) { filtered }
      error.define_singleton_method(:to_s) { filtered }
      error.define_singleton_method(:detailed_message) { |**| filtered }
      error
    end

    def redact_error_message(message)
      message.is_a?(String) ? message.sub(LITERALS, FILTERED_LITERAL) : message
    end

    private
      def server_error_code(error)
        error.respond_to?(:error_code) && error.error_code
      end

      def reference_to(table)
        name = Regexp.escape(table)
        /`#{name}`|"#{name}"|\b#{name}\.(?:PRIMARY\b|index_)|\bindex_#{name}_/
      end
  end
end

# Prepended, so it runs before every other sql.active_record consumer: Rails' structured event (and through
# it the log), Sentry's breadcrumbs and spans, and anything subscribed later. It replaces the payload's
# diagnostic fields after the statement has run, never the SQL string or binds the adapter executed, and
# clears both bind fields so no later consumer can recover a bound value. A failed statement's payload
# carries its error's message, which ErrorTranslation below has already filtered.
#
# Two boundaries. While Relation#explain collects queries it re-runs each one from this payload, so a
# statement run inside explain keeps its SQL, in its log line too; nothing in the app calls explain, and
# whoever does sees the values in its output anyway. And an evented subscriber's start callback runs before any
# finish, so it sees the raw payload; nothing installed reads SQL at start.
ActiveRecordSqlRedaction::SUBSCRIBER = ActiveSupport::Notifications.subscribe("sql.active_record", prepend: true) do |event|
  payload = event.payload

  if ActiveRecordSqlRedaction.redacted_statement?(payload[:sql]) && !ActiveRecord::ExplainRegistry.collect?
    payload[:sql] = ActiveRecordSqlRedaction.redact(payload[:sql])
    payload[:binds] = []
    payload[:type_casted_binds] = []
  end
end

module ActiveRecordSqlRedaction::ErrorTranslation
  private
    def translate_exception_class(native_error, sql, binds)
      if ActiveRecordSqlRedaction.redacted_statement?(sql) && \
          ActiveRecordSqlRedaction::UNFILTERED_ERROR_CODES.exclude?(native_error.try(:error_code))
        ActiveRecordSqlRedaction.filter_error(native_error)
      end

      super
    end
end

# Raised before the statement runs, with the statement in its message.
module ActiveRecordSqlRedaction::ReadOnlyErrorMessage
  def initialize(message = nil)
    super(ActiveRecordSqlRedaction.redacted_statement?(message) ? ActiveRecordSqlRedaction.redact_error_message(message) : message)
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::ConnectionAdapters::AbstractAdapter.prepend(ActiveRecordSqlRedaction::ErrorTranslation)
  ActiveRecord::ReadOnlyError.prepend(ActiveRecordSqlRedaction::ReadOnlyErrorMessage)
end
