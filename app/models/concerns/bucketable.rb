module Bucketable
  extend ActiveSupport::Concern

  TYPES = %w[ Project Filter ]

  included do
    has_one :bucket, as: :bucketable, dependent: :destroy

    after_create { create_bucket! account: account }
  end

  def title
    raise NotImplementedError
  end

  def cacheable?
    true
  end
end
