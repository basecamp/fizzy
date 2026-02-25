class Account::DataImportJob < ApplicationJob
  include ActiveJob::Continuable

  queue_as :backend
  discard_on Account::DataTransfer::RecordSet::IntegrityError, ZipFile::InvalidFileError

  def perform(import)
    step :check do |step|
      import.check \
        start: step.cursor,
        callback: ->(record_set:, file:) { step.set!([ record_set.model.name, file ]) }
    end

    step :process do |step|
      import.process \
        start: step.cursor,
        callback: ->(record_set:, files:) { step.set!([ record_set.model.name, files.last ]) }
    end
  end
end
