class Storage::ReconcileJob < ApplicationJob
  class ReconcileAborted < StandardError; end

  queue_as :backend
  limits_concurrency to: 1, key: ->(owner) { owner }

  discard_on ActiveJob::DeserializationError

  retry_on ReconcileAborted, wait: 1.minute, attempts: 3

  def perform(owner)
    raise ReconcileAborted, "Could not get stable snapshot for #{owner.class}##{owner.id}" unless owner.reconcile_storage
  end
end
