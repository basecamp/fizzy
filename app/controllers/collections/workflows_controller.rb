class Buckets::WorkflowsController < ApplicationController
  include BucketScoped

  before_action :set_workflow

  def update
    @bucket.update! workflow: @workflow

    redirect_to bubbles_path(bucket_ids: [ @bucket ])
  end

  private
    def set_workflow
      @workflow = Current.account.workflows.find(params.expect(bucket: [ :workflow_id ]).require(:workflow_id))
    end
end
