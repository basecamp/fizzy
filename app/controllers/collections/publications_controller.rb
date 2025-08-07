class Collections::PublicationsController < ApplicationController
  include CollectionScoped

  def create
    @collection.publish
    render turbo_stream: [
        turbo_stream.replace([ @collection, :publication ], partial: "collections/edit/publication", locals: { collection: @collection }),
        turbo_stream_flash(notice: "Saved")
      ]
  end

  def destroy
    @collection.unpublish
    @collection.reload
    render turbo_stream: [
        turbo_stream.replace([ @collection, :publication ], partial: "collections/edit/publication", locals: { collection: @collection }),
        turbo_stream_flash(notice: "Saved")
      ]
  end
end
