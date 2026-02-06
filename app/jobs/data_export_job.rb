class DataExportJob < ApplicationJob
  queue_as :backend

  discard_on ActiveJob::DeserializationError

  def perform(export)
    export.build
  end
end
