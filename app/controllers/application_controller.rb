class ApplicationController < ActionController::Base
  include Authentication
  include Authorization
  include BlockSearchEngineIndexing
  include CurrentRequest, CurrentTimezone, SetPlatform
  include RequestForgeryProtection
  include TurboFlash, ViewTransitions
  include RoutingHeaders

  etag { "v1" }
  stale_when_importmap_changes
  allow_browser versions: :modern

  def swap_theme()
    if cookies[:theme] == "dark"
      cookies[:theme] = "light"
    else
      cookies[:theme] = "dark"
    end

    redirect_back(fallback_location: root_path)
  end

end
