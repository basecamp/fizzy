#!/usr/bin/env ruby

require_relative "../../config/environment"

ApplicationRecord.with_each_tenant do |tenant|
  puts "🏢 #{tenant}"
  User.find_each do |user|
    next if user.system? || !user.active?

    if user.membership.present?
      puts "✅ User #{user.id} has a membership"
    else
      puts "⏩ Creating membership for user #{user.id}"

      identity = Identity.find_or_create_by(email_address: user.email_address)
      membership = identity.memberships.find_or_create_by(tenant: tenant)
      user.update_columns(membership_id: membership.id)
    end
  end
end
