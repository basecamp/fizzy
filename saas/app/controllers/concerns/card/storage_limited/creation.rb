module Card::StorageLimited::Creation
  extend ActiveSupport::Concern

  included do
    include Card::StorageLimited

    before_action :ensure_within_storage_limit, only: :create, if: -> { request.format.json? }
  end
end
