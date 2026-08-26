class Account::DataImportJob < ApplicationJob
  include ActiveJob::Continuable

  # Errors that must reach the discard_on handlers instead of resuming the
  # continuation, which would re-run the import against them. Transient errors
  # (network, database) still resume from the step cursor as usual.
  TERMINAL_ERRORS = [ Account::DataTransfer::RecordSet::IntegrityError, ZipFile::InvalidFileError,
    Account::Import::InsufficientStorageSpaceError ].freeze

  queue_as :backend
  discard_on(*TERMINAL_ERRORS)

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

  private
    def resume_job(exception)
      TERMINAL_ERRORS.any? { |terminal| exception.is_a?(terminal) } ? raise(exception) : super
    end
end
