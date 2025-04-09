class Buckets::InvolvementsController < ApplicationController
  include BucketScoped

  def update
    @bucket.access_for(Current.user).update!(involvement: params[:involvement])
  end
end
