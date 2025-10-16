# frozen_string_literal: true

task "db_migrate_queue_zones" => :environment do
  if Rails.application.config.active_job.queue_adapter == :solid_queue
    config = SolidQueue::Record.tenanted_root_config
    raise "Unexpected db config for Solid Queue" unless ActiveRecord::Tenanted::DatabaseConfigurations::BaseConfig === config

    tasks = ActiveRecord::Tenanted::DatabaseTasks.new(config)

    FIZZY_ZONES.each do |zone|
      # TODO: the beamer-rails gem should offer an API for this
      if system("bin/beamer -d ./storage is-primary --zone #{zone.inspect} 2> /dev/null")
        $stdout.puts "Preparing Fizzy's Solid Queue database for zone #{zone.inspect}"
        tasks.migrate_tenant(zone)
      end
    end
  end
end

task "db:seed" => "db_migrate_queue_zones"
task "db:migrate:queue" => "db_migrate_queue_zones"
task "db:prepare" => "db_migrate_queue_zones"
