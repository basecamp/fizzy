class ApplicationController < ActionController::Base
  include Authentication
  include Authorization
  include CurrentRequest, CurrentTimezone, SetPlatform
  include TurboFlash, ViewTransitions
  include Saas
  include RoutingHeaders, WriterAffinity

  etag { "v1" }
  stale_when_importmap_changes
end
