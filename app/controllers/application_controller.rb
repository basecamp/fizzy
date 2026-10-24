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
  RENDERING_VERSION = "v2"

  fragment_cache_key RENDERING_VERSION
  etag { RENDERING_VERSION }
  stale_when_importmap_changes
  allow_browser versions: :modern
end
