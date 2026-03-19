module Account::StorageLimited
  extend ActiveSupport::Concern

  STORAGE_LIMIT = 1.gigabyte
  NEAR_STORAGE_LIMIT_THRESHOLD = 500.megabytes

  def exceeding_storage_limit?
    bytes_used > STORAGE_LIMIT
  end

  def nearing_storage_limit?
    !exceeding_storage_limit? && bytes_used > STORAGE_LIMIT - NEAR_STORAGE_LIMIT_THRESHOLD
  end
end
