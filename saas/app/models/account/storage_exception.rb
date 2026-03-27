class Account::StorageException < SaasRecord
  belongs_to :account

  validates :bytes_allowed, presence: true, numericality: { greater_than: 0 }
end
