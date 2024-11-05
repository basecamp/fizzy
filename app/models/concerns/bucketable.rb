module Bucketable
  extend ActiveSupport::Concern

  TYPES = %w[ Project Filter ]

  included do
    has_one :bucket, as: :bucketable, dependent: :destroy, touch: true

    after_create { create_bucket! account: account }
  end

  def title
    raise NotImplementedError
  end
end
