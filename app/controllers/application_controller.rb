class ApplicationController < ActionController::Base
  include Authentication, CurrentRequest, CurrentTimezone, SetPlatform, TurboFlash, WriterAffinity

  stale_when_importmap_changes
  allow_browser versions: :modern
end
