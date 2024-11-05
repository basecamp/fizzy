class Bucket < ApplicationRecord
  include Accessible

  belongs_to :account

  has_many :bubbles, dependent: :destroy
  has_many :tags, -> { distinct }, through: :bubbles

  delegated_type :bucketable, types: Bucketable::TYPES, inverse_of: :bucket, dependent: :destroy

  scope :reverse_chronologically, -> { order created_at: :desc, id: :desc }

  delegate :title, :creator, :cacheable?, to: :bucketable
end
