class Account::DataImportJob < ApplicationJob
  include ActiveJob::Continuable

  # Let errors reach the discard_on/failure handlers instead of resuming the
  # continuation, which would re-run the import against terminal errors like
  # conflicts. Deploy interruptions still resume via Continuation::Interrupt.
  self.resume_errors_after_advancing = false

  queue_as :backend
  discard_on Account::DataTransfer::RecordSet::IntegrityError, ZipFile::InvalidFileError,
    Account::Import::InsufficientStorageSpaceError

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
