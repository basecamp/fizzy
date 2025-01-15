class Buckets::BubbleLimitsController < ApplicationController
  include BucketScoped

  def update
    @bucket.update! bubble_limit: params[:bubble_limit]
  end
end
