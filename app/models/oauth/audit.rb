# OAuth lifecycle events, in the 37signals OAuth Standard's vocabulary
# (oauth.grant.created, oauth.token.refreshed, …), reported through Rails.event.
# Fizzy itself subscribes nothing: the SaaS engine writes each event to the
# structured log and counts it in Yabeda, and a self-hosted install may
# subscribe whatever it likes.
#
# Every event carries the same fields, so one query reads them all. A field
# that doesn't apply is nil rather than absent. Identity and tenant are the
# ids the request log already records (authentication.identity.id and
# account.queenbee_id), and request_id is the request log's transaction id,
# which is where the IP address and user agent stay: an event repeats no
# personal data. It never carries a token, refresh token, client secret or
# their digests either. Rails.event also masks any field named like one
# (filter_parameters), but nothing here should depend on that.
module Oauth::Audit
  APP = "fizzy"

  ACTORS = %w[ user admin system client ]

  extend self

  # The identity is the grant's, or one named explicitly, never whoever
  # happens to be signed in: a browser with a session can register a client
  # too, and that registration is no act of theirs.
  def record(event, grant: nil, client: grant&.oauth_client, identity_id: grant&.identity_id, actor:, reason: nil, **details)
    raise ArgumentError, "unknown actor #{actor.inspect}" unless actor.in?(ACTORS)

    name = "oauth.#{event}"

    Rails.event.notify name,
      app: APP,
      event: name,
      client_id: client&.client_id,
      client_class: client_class(grant: grant, client: client),
      client_type: client&.client_type,
      # Fizzy keeps one row per grant and rotates its tokens in place, so the
      # grant is the refresh token family.
      grant_id: grant&.id,
      family_id: grant&.id,
      identity_id: identity_id,
      # Grants span an identity's accounts, so OAuth requests run outside any
      # account and this is usually nil.
      tenant_id: Current.account&.external_account_id,
      actor: actor,
      reason: reason,
      request_id: Current.request_id,
      **details
  end

  private
    def client_class(grant:, client:)
      if client
        if client.dynamically_registered?
          "dcr"
        elsif client.trusted?
          "first_party"
        else
          "partner"
        end
      elsif grant && !grant.oauth_client_id?
        "pat"
      end
    end
end
