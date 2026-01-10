class Mention::CreateJob < ApplicationJob
  discard_on ActiveJob::DeserializationError

  def perform(record, mentioner:)
    record.create_mentions(mentioner:)
  end
end
