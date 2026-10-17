module Fizzy
  module Saas
    # Sentry reads SQL from the sql.active_record notification itself, upstream of the log redaction in
    # lib/rails_ext/active_record_sql_redaction.rb, so its breadcrumbs and spans are redacted here.
    module SentrySqlRedaction
      extend self

      def install(config)
        config.before_breadcrumb = method(:before_breadcrumb)
        config.before_send = method(:before_send)
        config.before_send_transaction = method(:before_send_transaction)
      end

      def before_breadcrumb(breadcrumb, _hint)
        breadcrumb.tap do
          if breadcrumb.data.is_a?(Hash) && breadcrumb.data.key?(:sql)
            breadcrumb.data[:sql] = ActiveRecordSqlRedaction.redact(breadcrumb.data[:sql])
          end
        end
      end

      # Database errors on redacted tables are filtered where Active Record translates them; this catches
      # one that reached Sentry another way.
      def before_send(event, _hint)
        event.tap do
          event.exception&.values&.each do |value|
            value.value = ActiveRecordSqlRedaction::FILTERED_ERROR if ActiveRecordSqlRedaction.mentions_redacted_table?(value.value)
          end
        end
      end

      # Fizzy doesn't sample transactions today; this keeps spans redacted if it starts to.
      def before_send_transaction(event, _hint)
        event.tap do
          event.spans&.each do |span|
            span[:description] = ActiveRecordSqlRedaction.redact(span[:description]) if span[:op].to_s.start_with?("db")
          end
        end
      end
    end
  end
end
