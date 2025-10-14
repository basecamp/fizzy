class ApplicationController < ActionController::Base
  include Authentication, Authorization, CurrentRequest, CurrentTimezone, SetPlatform, TurboFlash, ViewTransitions, WriterAffinity

  stale_when_importmap_changes
  allow_browser versions: :modern, block: -> { render "errors/not_acceptable", layout: "error" }
end
