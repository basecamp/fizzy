class Collections::WorkflowsController < ApplicationController
  include CollectionScoped

  before_action :set_workflow

  def update
    @collection.update! workflow: @workflow
    render turbo_stream: [
        turbo_stream.replace([ @collection, :workflows ], partial: "collections/edit/workflows", locals: { collection: @collection }),
        turbo_stream_flash(notice: "Saved")
      ]
  end

  private
    def set_workflow
      workflow_id = params[:collection][:workflow_id]
      @workflow = workflow_id.present? ? Workflow.find(workflow_id) : nil
    end
end
