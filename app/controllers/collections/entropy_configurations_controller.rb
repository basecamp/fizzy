class Collections::EntropyConfigurationsController < ApplicationController
  include CollectionScoped

  def update
    @collection.entropy_configuration.update!(entropy_configuration_params)

    render turbo_stream: [
        turbo_stream.replace([ @collection, :entropy_configuration ], partial: "collections/edit/auto_close", locals: { collection: @collection }),
        turbo_stream_flash(notice: "Saved")
      ]
  end

  private
    def entropy_configuration_params
      params.expect(collection: [ :auto_close_period, :auto_reconsider_period ])
    end
end
