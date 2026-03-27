module Card::StorageLimited::Commenting
  extend ActiveSupport::Concern

  included do
    include Card::StorageLimited

    before_action :ensure_within_storage_limit, only: :create
  end
end
