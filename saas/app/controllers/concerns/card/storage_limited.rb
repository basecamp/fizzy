module Card::StorageLimited
  extend ActiveSupport::Concern

  private
    def ensure_within_storage_limit
      head :forbidden if Current.account.exceeding_storage_limit? && !Current.identity.staff?
    end
end
