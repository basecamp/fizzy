class ApplicationController < ActionController::Base
  include Authentication, Authorization, CurrentRequest, CurrentTimezone, DisableWriterAffinity,
    LoadBalancerRouting, SetPlatform, TurboFlash, ViewTransitions

  stale_when_importmap_changes
  allow_browser versions: :modern, block: -> { render "errors/not_acceptable", layout: "error" }
end
