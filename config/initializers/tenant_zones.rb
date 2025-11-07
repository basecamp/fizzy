BEAMER_ZONES = ENV.fetch("BEAMER_ZONES", "default").split

module ApplicationRecordWithTenantZoneExtension
  extend ActiveSupport::Concern

  class_methods do
    def with_solid_queue_zone(&block)
      SolidQueue::Record.with_tenant(solid_queue_zone, &block)
    end

    def set_solid_queue_zone
      SolidQueue::Record.current_tenant = solid_queue_zone
    end

    def solid_queue_zone
      if current_tenant.present? && tenant_exist?(current_tenant) && ApplicationRecord.tenanted_root_config.adapter == "beamer"
        # Production environment, tenanted context
        # TODO: move this into the beamer gem and/or replace it with ReplicationCoordinator
        ApplicationRecord.connection.beamer_zone
      elsif ENV["SOLID_QUEUE_ZONE"].present?
        # Production environment, untenanted context
        ENV["SOLID_QUEUE_ZONE"]
      elsif BEAMER_ZONES.one?
        # Dev or test
        BEAMER_ZONES.first
      else
        # Probably something is misconfigured, let's prevent writes.
        ActiveRecord::Tenanted::Tenant::UNTENANTED_SENTINEL
      end
    end
  end

  included do
    if Rails.application.config.active_job.queue_adapter == :solid_queue
      set_callback :with_tenant,        :around, :with_solid_queue_zone
      set_callback :set_current_tenant, :after,  :set_solid_queue_zone
    end
  end
end

if Rails.application.config.active_job.queue_adapter == :solid_queue
  ActiveSupport.on_load(:solid_queue_record) do
    tenanted :queue
  end

  Rails.application.config.after_initialize do
    # The simplifying assumption here is that a SQ process will only ever write to one zone, so we
    # can simply set and clear the tenant before and after execution with `current_tenant=` and not
    # worry about implementing a custom Executor that wraps execution using `with_tenant`.
    SolidQueue.app_executor.to_run :before do
      SolidQueue::Record.current_tenant = ApplicationRecord.solid_queue_zone
    end

    SolidQueue.app_executor.to_complete :after do
      SolidQueue::Record.current_tenant = ActiveRecord::Tenanted::Tenant::UNTENANTED_SENTINEL
    end
  end

  Rails.application.config.to_prepare do
    ApplicationRecord.include ApplicationRecordWithTenantZoneExtension

    SolidQueue::Record.current_tenant = ApplicationRecord.solid_queue_zone
  end
end
