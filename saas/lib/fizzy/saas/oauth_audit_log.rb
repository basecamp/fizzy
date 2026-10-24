module Fizzy
  module Saas
    # Writes each OAuth audit event (Oauth::Audit) to the structured log as a
    # line of its own, in the same ECS shape as the request and job lines
    # beside it, so Loki collects it with them. A Rails.event subscriber.
    #
    # Its own line, rather than fields merged into the request's line with
    # logger.struct, because one request can report several events (a code
    # exchange redeems a code, creates a grant and issues a token), and the
    # sweeps report theirs from jobs. transaction.id is the request's id, as
    # on the request line, so the two join.
    #
    # The event's fields are written as reported, and they hold no credential
    # or personal data the request log doesn't already carry (see
    # Oauth::Audit).
    class OauthAuditLog
      def initialize(logger)
        @logger = logger
      end

      def emit(event)
        @logger.info JSON.generate(line_for(event))
      end

      private
        def line_for(event)
          {
            "@timestamp": Time.at(0, event[:timestamp], :nsec).utc.iso8601(6),
            ecs: { version: "1.2.0" },
            event: { action: event[:name] },
            transaction: { id: event[:payload][:request_id] },
            oauth: event[:payload],
            rails: { application: Rails.application.railtie_name.delete_suffix("_application"), env: Rails.env }
          }
        end
    end
  end
end
