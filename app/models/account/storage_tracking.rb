module Account::StorageTracking
  extend ActiveSupport::Concern

  def adjust_storage(delta)
    increment!(:bytes_used, delta)
  end

  def adjust_storage_later(delta)
    Account::AdjustStorageJob.perform_later(self, delta) unless delta.zero?
  end

  def recalculate_bytes_used
    boards.find_each(&:recalculate_bytes_used)
    update_columns bytes_used: boards.sum(:bytes_used)
  end
end
