class ImportAccountDataJob < ApplicationJob
  include ActiveJob::Continuable

  queue_as :backend

  def perform(import)
    step :validate do
      import.validate \
        start: step.cursor,
        callback: proc { |record_set:, record_id:| step.set! [ record_set, record_id ] }
    end

    step :process do
      import.process \
        start: step.cursor,
        callback: proc { |record_set:, record_id:| step.set! [ record_set, record_id ] }
    end
  end
end
