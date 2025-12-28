# rbs_inline: enabled

class ApplicationController < ActionController::Base
  include Authentication
  include Authorization
  include BlockSearchEngineIndexing
  include CurrentRequest, CurrentTimezone, SetPlatform
  include RequestForgeryProtection
  include TurboFlash, ViewTransitions
  include RoutingHeaders

  # @rbs!
  #   def set_page_and_extract_portion_from: (ActiveRecord::Relation) -> void
  #   def turbo_stream: -> untyped
  #   def self.stale_when_importmap_changes: -> void

  etag { "v1" }
  stale_when_importmap_changes
  allow_browser versions: :modern
end
