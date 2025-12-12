class Storage::ReconcileJob < ApplicationJob
  queue_as :backend

  discard_on ActiveJob::DeserializationError

  def perform(owner)
    owner.reconcile_storage
  end
end
