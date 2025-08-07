#!/usr/bin/env ruby
#
# This script creates a new user that can be logged into via LOCAL_AUTHENTICATION, avoiding Launchpad/37id integration.
# In order to login as this user, you must set the `LOCAL_AUTHENTICATION` environment variable when running the Rails server:
#
#   LOCAL_AUTHENTICATION=1 bin/dev
#

require_relative "../config/environment"

unless Rails.env.development?
  puts "ERROR: This script is intended to be run in development mode only."
  exit 1
end

if ARGV.length < 2
  puts "Usage: #{$0} <email> <tenant>"
  exit 1
end

email_address = ARGV[0]
tenant = ARGV[1]

ApplicationRecord.with_tenant(tenant) do
  user = User.create!(
    name: email_address.split("@").first,
    email_address: email_address,
    password: "secret123456"
  )

  puts "Created: "
  pp user
end
