module Account::StorageLimited
  extend ActiveSupport::Concern

  DEFAULT_STORAGE_LIMIT = 1.gigabyte
  NEAR_STORAGE_LIMIT_THRESHOLD = 500.megabytes

  included do
    has_one :storage_exception
  end

  def storage_limit
    storage_exception&.bytes_allowed || DEFAULT_STORAGE_LIMIT
  end

  def exceeding_storage_limit?
    bytes_used > storage_limit
  end

  def nearing_storage_limit?
    !exceeding_storage_limit? && bytes_used > storage_limit - NEAR_STORAGE_LIMIT_THRESHOLD
  end

  def add_storage_exception(bytes)
    if storage_exception
      storage_exception.update!(bytes_allowed: bytes)
    else
      create_storage_exception!(bytes_allowed: bytes)
    end
  end
end
