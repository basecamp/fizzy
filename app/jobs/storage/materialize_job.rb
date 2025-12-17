class Storage::MaterializeJob < ApplicationJob
  queue_as :backend
  limits_concurrency to: 1, key: ->(owner) { owner }

  discard_on ActiveJob::DeserializationError

  def perform(owner)
    owner.materialize_storage
  end
end
