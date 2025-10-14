#!/usr/bin/env ruby

if ARGV.length != 1
  puts "Usage: #{$0} <dbfile>"
  exit 1
end
original_dbfile = ARGV[0]

require "securerandom"
identifier = SecureRandom.hex(4)

# run a process to run the migration and dump the schema cache
Process.fork do
  require_relative "../config/environment"

  unless Rails.env.local?
    abort "This script should only be run in a local development environment."
  end

  tenant = ActiveRecord::FixtureSet.identify(identifier)

  path = ApplicationRecord.tenanted_root_config.database_path_for(tenant)
  FileUtils.mkdir_p(File.dirname(path), verbose: true)
  FileUtils.cp original_dbfile, path, verbose: true

  ActiveRecord::Tenanted::DatabaseTasks.migrate_all
end
Process.wait

# now load the schema cache and do what we need to do in the database
require_relative "../config/environment"

tenant = ActiveRecord::FixtureSet.identify(identifier)

ApplicationRecord.with_tenant(tenant) do |tenant|
  Account.sole.destroy!

  Account.create_with_admin_user \
    account: { name: "Company #{identifier}" },
    owner: { name: "Developer #{identifier}", email_address: "dev-#{identifier}@example.com", password: "secret123456" }

  user = User.last
  Collection.find_each do |collection|
    collection.accesses.grant_to(user)
  end

  url = Rails.application.routes.url_helpers.root_url(Rails.application.config.action_controller.default_url_options.merge(script_name: Account.sole.slug))
  puts "\n\nLogin to #{url} as #{user.email_address} / secret123456"
end
