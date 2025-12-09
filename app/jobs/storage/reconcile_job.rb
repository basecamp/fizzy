class Storage::ReconcileJob < ApplicationJob
  queue_as :backend

  def perform(owner)
    owner.reconcile_storage
  end
end
