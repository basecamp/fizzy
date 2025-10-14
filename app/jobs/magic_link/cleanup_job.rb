class MagicLink::CleanupJob < ApplicationJob
  def perform
    MagicLink.cleanup
  end
end
