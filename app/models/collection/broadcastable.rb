module Bucket::Broadcastable
  extend ActiveSupport::Concern

  included do
    broadcasts_refreshes
    broadcasts_refreshes_to ->(bucket) { [ bucket.account, :buckets ] }
  end
end
