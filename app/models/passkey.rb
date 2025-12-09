class Passkey < ApplicationRecord
  belongs_to :identity

  validates :external_id, presence: true, uniqueness: true
  validates :public_key, presence: true
end
