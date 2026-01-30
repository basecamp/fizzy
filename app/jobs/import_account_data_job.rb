class ImportAccountDataJob < ApplicationJob
  include ActiveJob::Continuable

  queue_as :backend

  def perform(import)
    step :check do
      import.check \
        start: step.cursor,
        callback: proc do |record_set:, file:|
          step.set!([ record_set.model.name, file ])
        end
    end

    step :process do
      import.process \
        start: step.cursor,
        callback: proc do |record_set:, files:|
          step.set!([ record_set.model.name, files.last ])
        end
    end
  end
end
