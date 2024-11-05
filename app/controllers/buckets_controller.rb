class BucketsController < ApplicationController
  def index
    @buckets = Current.user.buckets.reverse_chronologically
    fresh_when @buckets
  end
end
