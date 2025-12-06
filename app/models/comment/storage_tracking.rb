module Comment::StorageTracking
  extend ActiveSupport::Concern

  included do
    include ::StorageTracking
  end

  def bytes_used_changed(delta)
    card.bytes_used_changed(delta)
  end
end
