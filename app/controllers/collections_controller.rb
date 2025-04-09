class BucketsController < ApplicationController
  before_action :set_bucket, except: %i[ new create ]

  def new
    @bucket = Current.account.buckets.build
  end

  def create
    @bucket = Current.account.buckets.create! bucket_params
    redirect_to bubbles_path(bucket_ids: [ @bucket ])
  end

  def edit
    selected_user_ids = @bucket.users.pluck :id
    @selected_users, @unselected_users = User.active.alphabetically.partition { |user| selected_user_ids.include? user.id }
  end

  def update
    @bucket.update! bucket_params
    @bucket.accesses.revise granted: grantees, revoked: revokees

    redirect_to bubbles_path(bucket_ids: [ @bucket ])
  end

  def destroy
    @bucket.destroy
    redirect_to root_path
  end

  private
    def set_bucket
      @bucket = Current.user.buckets.find params[:id]
    end

    def bucket_params
      params.expect(bucket: [ :name, :all_access ]).with_defaults(all_access: true)
    end

    def grantees
      Current.account.users.active.where id: grantee_ids
    end

    def revokees
      @bucket.users.where.not id: grantee_ids
    end

    def grantee_ids
      params.fetch :user_ids, []
    end
end
