# The OAuth Standard's metrics (OB-1), under bc3's names and labels so one
# dashboard reads both apps; the scrape adds app="fizzy". Fizzy has a subset
# of bc3's surfaces, so it exports a subset of bc3's series, plus the proposed
# oauth_replays_total.
#
# Core code doesn't know Yabeda exists. Lifecycle changes arrive as the audit
# events Oauth::Audit reports through Rails.event, and the rest (errors,
# throttling, timing, sweep failures) as Active Support notifications named
# *.oauth.
#
# Every label value comes from a fixed set in the code, never from a request:
# client ids in particular are never labels, since anyone can register a
# client and mint one.
module Yabeda
  module Oauth
    # Grants span an identity's accounts; there are no account-scoped grants.
    ACCOUNT_SCOPE = "identity"

    # The endpoints whose errors are token errors: the token endpoint and its
    # RFC 7009 sibling, which authenticates clients the same way, so an
    # invalid_client spike shows across both. Registration errors are
    # dcr_rejections_total instead.
    TOKEN_ERROR_ENDPOINTS = %w[ tokens revocations ]

    def self.install!
      Yabeda.configure do
        group :oauth do
          counter :token_grants_total, comment: "OAuth token grants issued",
            tags: %i[ grant_type client_type ]
          counter :token_errors_total, comment: "OAuth token endpoint errors",
            tags: %i[ error_code client_type ]
          counter :authorization_grants_total, comment: "OAuth authorization grants created",
            tags: %i[ client_type account_scope ]
          counter :authorization_denials_total, comment: "OAuth authorization denials",
            tags: %i[ client_type ]
          counter :revocations_total, comment: "OAuth token revocations by a user or client",
            tags: %i[ token_type initiator ]
          counter :family_revocations_total, comment: "OAuth grants ended by the server, by reason (reuse_detected and code_replayed are the theft signal)",
            tags: %i[ reason ]
          counter :replays_total, comment: "Rotated refresh tokens presented again: a retry within the grace window, or reuse past it",
            tags: %i[ kind ]
          counter :dcr_registrations_total, comment: "Dynamic client registrations"
          counter :dcr_rejections_total, comment: "Dynamic client registrations rejected, by OAuth error code (rate-limit refusals are in rate_limit_hits_total)",
            tags: %i[ reason ]
          counter :rate_limit_hits_total, comment: "OAuth rate limit hits",
            tags: %i[ endpoint ]
          counter :cleanup_step_failures_total, comment: "OAuth cleanup job step failures",
            tags: %i[ step ]
          histogram :token_request_duration_seconds, comment: "OAuth token request duration",
            tags: %i[ grant_type ],
            buckets: [ 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5 ]
        end

        ::Rails.event.subscribe(Yabeda::Oauth::Events.new) { |event| event[:name].start_with?("oauth.") }

        ActiveSupport::Notifications.subscribe "token_request.oauth" do |event|
          oauth_token_request_duration_seconds.measure({ grant_type: event.payload[:grant_type] }, event.duration / 1000.0)
        end

        ActiveSupport::Notifications.subscribe "error.oauth" do |event|
          payload = event.payload

          if payload[:endpoint].in?(TOKEN_ERROR_ENDPOINTS)
            oauth_token_errors_total.increment({ error_code: payload[:error_code], client_type: payload[:client_type] })
          elsif payload[:endpoint] == "clients"
            oauth_dcr_rejections_total.increment({ reason: payload[:error_code] })
          end
        end

        ActiveSupport::Notifications.subscribe "rate_limit.oauth" do |event|
          oauth_rate_limit_hits_total.increment({ endpoint: event.payload[:endpoint] })
        end

        ActiveSupport::Notifications.subscribe "cleanup_failure.oauth" do |event|
          oauth_cleanup_step_failures_total.increment({ step: event.payload[:step].to_s })
        end
      end
    end

    # Counts Oauth::Audit's events. A Rails.event subscriber.
    class Events
      def emit(event)
        payload = event[:payload]

        case event[:name]
        when "oauth.token.issued", "oauth.token.refreshed"
          Yabeda.oauth.token_grants_total.increment({ grant_type: payload[:grant_type], client_type: payload[:client_type] })
        when "oauth.consent.approved"
          Yabeda.oauth.authorization_grants_total.increment({ client_type: payload[:client_type], account_scope: ACCOUNT_SCOPE })
        when "oauth.consent.denied"
          Yabeda.oauth.authorization_denials_total.increment({ client_type: payload[:client_type] })
        when "oauth.grant.revoked", "oauth.pat.revoked"
          count_revocation payload
        when "oauth.token.grace_replay"
          Yabeda.oauth.replays_total.increment({ kind: "grace" })
        when "oauth.token.reuse_detected"
          Yabeda.oauth.replays_total.increment({ kind: "reuse" })
        when "oauth.client.registered"
          Yabeda.oauth.dcr_registrations_total.increment({}) if payload[:client_class] == "dcr"
        end
      end

      private
        # A person or client revoking is revocations_total, labeled as bc3
        # labels it: the token presented at the revocation endpoint, "grant"
        # for an app disconnected, "access" for a personal access token.
        # Anything the server ends on its own is family_revocations_total.
        def count_revocation(payload)
          if payload[:actor] == "system"
            Yabeda.oauth.family_revocations_total.increment({ reason: payload[:reason] })
          else
            token_type = payload[:presented] || (payload[:client_class] == "pat" ? "access" : "grant")
            Yabeda.oauth.revocations_total.increment({ token_type: token_type, initiator: payload[:actor] })
          end
        end
    end
  end
end
