class ExportAccountDataJob < ApplicationJob
  queue_as :backend

  def perform(export)
    export.build
  end
end
