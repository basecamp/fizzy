#!/usr/bin/env ruby

require_relative "config/environment"

Rails.logger.level = Logger::WARN

data = []

if ARGV.length < 1
  puts "Usage: #{$0} <output_file>"
end

output_file = ARGV[0]

FileUtils.rm_rf "storage/tenants/#{Rails.env}", verbose: true
FileUtils.rm_f Dir.glob("storage/#{Rails.env}*.sqlite3"), verbose: true

system "bin/rails db:prepare"

10.times.map do
  signup = Signup.new(
    company_name: "#{SecureRandom.hex(4)} LLC",
    email_address: "load-test-dev-#{SecureRandom.hex(4)}@example.com",
    full_name: "Load Test",
    password: SecureRandom.hex(12)
  )
  signup.process || raise("Failed to create tenant: #{signup.errors.full_messages.join(", ")}")
  tenant = signup.tenant_name

  ApplicationRecord.with_tenant(tenant) do
    puts "Created tenant #{tenant} for #{signup.company_name.inspect}"
    data << { tenant: tenant, transfer_id: User.first.transfer_id }

    10.times do
      Card.create!(collection_id: 1, creator: User.first, title: "Load Test Card #{SecureRandom.hex(4)}", description: "This is a load test card for tenant #{tenant}.")
    end
  end
end

File.write(output_file, JSON.pretty_generate(data))
