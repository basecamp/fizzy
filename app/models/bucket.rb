class Bucket < ApplicationRecord
  include Accessible

  belongs_to :account

  has_many :bubbles, dependent: :destroy
  has_many :tags, -> { distinct }, through: :bubbles

  delegated_type :bucketable, types: Bucketable::TYPES, inverse_of: :bucket, dependent: :destroy

  scope :by_recency, -> { order updated_at: :desc }

  delegate :title, :creator, to: :bucketable
end
