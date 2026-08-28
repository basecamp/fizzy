module Identity::Transferable
  extend ActiveSupport::Concern

  included do
    has_many :transfers, class_name: "Identity::Transfer", dependent: :delete_all
  end

  class_methods do
    def find_by_transfer_id(token)
      Identity::Transfer.consume(token)&.identity
    end
  end

  def transfer
    transfers.active.first
  end

  def transfer_id
    transfers.create!.token
  end

  def regenerate_transfer_token
    transfers.delete_all
    transfers.create!
  end
end
