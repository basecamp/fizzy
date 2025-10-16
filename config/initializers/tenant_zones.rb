FIZZY_ZONES = %w[ iad-01 chi-01 ams-01 ]

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
      if current_tenant.present? && tenant_exist?(current_tenant)
        # TODO: move this into the beamer gem and/or replace it with ReplicationCoordinator
        ApplicationRecord.connection.beamer_zone
      elsif ENV["SOLID_QUEUE_ZONE"].present?
        ENV["SOLID_QUEUE_ZONE"]
      else
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
    if ApplicationRecord.tenanted_root_config.adapter == "beamer"
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
  end

  Rails.application.config.to_prepare do
    if ApplicationRecord.tenanted_root_config.adapter == "beamer"
      ApplicationRecord.include ApplicationRecordWithTenantZoneExtension
    end

    if ENV["SOLID_QUEUE_ZONE"].present?
      # This will be the default queue for untenanted actions
      SolidQueue::Record.current_tenant = ENV["SOLID_QUEUE_ZONE"]
    end
  end
end
