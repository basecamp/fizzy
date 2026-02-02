Rails.application.configure do
  # SaaS version of Fizzy is multi-tenanted
  config.x.multi_tenant.enabled = true

  if Rails.root.join("tmp/structured-logging.txt").exist?
    config.structured_logging.logger = ActiveSupport::Logger.new("log/structured-development.log")
  end

  if Rails.root.join("tmp/solid-queue.txt").exist?
    config.active_job.queue_adapter = :solid_queue
    config.solid_queue.connects_to = { database: { writing: :queue, reading: :queue } }
  end
end
