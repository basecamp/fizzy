class ApplicationController < ActionController::Base
  include Authentication
  include Authorization
  include CurrentRequest, CurrentTimezone, SetPlatform
  include TurboFlash, ViewTransitions
  include Saas
  include RoutingHeaders, WriterAffinity

  stale_when_importmap_changes
  allow_browser versions: :modern

  etag { "v1" } # 2025-11-05 @todo: To invalidate HTTP cache after big renaming. To remove after a few days.
end
