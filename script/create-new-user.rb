#!/usr/bin/env ruby

require_relative "../config/environment"

if ARGV.length < 3
  puts "Usage: #{$0} <tenant> <email> <fullname>"
  exit 1
end

tenant = ARGV.shift
email_address = ARGV.shift
name = ARGV.join(" ")

begin
  ApplicationRecord.with_tenant(tenant) do
    password = SecureRandom.hex(16)

    user = User.create!(name:, email_address:, password:)
    puts "Created: "
    pp user

    puts "Password is: #{password.inspect}"
  end
rescue Exception => e
  puts "Failed with error: #{e.inspect}"
end
