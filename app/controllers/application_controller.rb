class ApplicationController < ActionController::Base
  include Authentication
  include Authorization
  include BlockSearchEngineIndexing
  include CurrentRequest, CurrentTimezone, SetPlatform
  include RequestForgeryProtection
  include TurboFlash, ViewTransitions
  include RoutingHeaders

  # Bump to retire every cached fragment and every browser's cached page at once. It expires
  # all fragment caches together, so expect a cold-cache load at rollout.
  #
  # v2: rich text sanitized under crass 1.0.7 could keep style declarations smuggled behind a
  # bad url (GHSA-pq4g-8rxf-4g29), and its fragments are keyed by record, not by the gem.
  # v3: rich text sanitized under loofah 2.25.2 and nokogiri 1.19.4 could keep a live url()
  # spelled with CSS escapes (GHSA-m3x9-938q-5767), javascript: and data:text/html URIs spelled
  # with character references (GHSA-p9wj-w8xq-vjx6, GHSA-jcff-cj73-4w4f), and unescaped < and >
  # in attribute values (GHSA-h6v6-rg66-fqj4).
  RENDERING_VERSION = "v3"

  fragment_cache_key RENDERING_VERSION
  etag { RENDERING_VERSION }
  stale_when_importmap_changes
  # People's browsers, that is: see allow_any_user_agent.
  class_attribute :browser_versions_enforced, instance_accessor: false, default: true
  allow_browser versions: :modern, if: -> { self.class.browser_versions_enforced }

  # For endpoints software calls rather than people visit: OAuth's token,
  # registration, revocation and discovery. Their callers send whatever
  # user agent their platform does, an old browser's included, and a 406 page
  # is no answer a client can act on.
  def self.allow_any_user_agent
    self.browser_versions_enforced = false
  end

  # Here rather than in Authentication: Active Storage's controllers include
  # that too, and a handler declared there would shadow ones added to their
  # base controller after.
  rescue_from Identity::AccessToken::Disconnected do
    request_bearer_authentication error: "invalid_token", error_description: "The access token is expired, revoked, or invalid"
  end
end
