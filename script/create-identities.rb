#!/usr/bin/env ruby

require_relative "../config/environment"

# Loop through all tenants and create identities for users
ApplicationRecord.with_each_tenant do |tenant|
  puts "Processing tenant: #{tenant}"

  User.find_each do |user|
    next if user.system?

    # Use IdentityProvider to link the user's email to this tenant
    # This will find_or_create the identity and link it to the tenant
    IdentityProvider.link(email_address: user.email_address, to: tenant)

    puts "  ✅ Linked identity for user #{user.id} (#{user.email_address}) to tenant '#{tenant}'"
  end

  puts "  Completed tenant: #{tenant}"
  puts
end

puts "All identities created successfully!"
