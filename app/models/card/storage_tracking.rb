module Card::StorageTracking
  extend ActiveSupport::Concern

  included do
    include ::StorageTracking
  end

  def bytes_used_changed(delta)
    board.bytes_used_changed(delta)
  end
end
