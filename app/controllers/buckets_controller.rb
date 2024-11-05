class BucketsController < ApplicationController
  def index
    @buckets = Current.user.buckets.by_recency
    fresh_when @buckets
  end
end
