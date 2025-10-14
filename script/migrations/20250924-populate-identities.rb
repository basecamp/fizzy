#!/usr/bin/env ruby

require_relative "../../config/environment"

ApplicationRecord.with_each_tenant do |tenant|
  puts "# #{tenant}"
  User.find_each do |user|
    next if user.system? || !user.active?

    if user.membership.present?
      puts "Found identity #{user.identity.id} for user #{user.id} (#{user.email_address})"
    else
      memberships = Membership.where(email_address: user.email_address)
      if memberships.empty?
        # Create a new Identity
        Identity.transaction do
          identity = Identity.create!
          user.membership = identity.memberships.create!(user_id: user.id, user_tenant: user.tenant, email_address: user.email_address, account_name: Account.sole.name)
          puts "Created identity #{identity.id} for user #{user.id} (#{user.email_address})"
        end
      else
        # Merge this User's Membership into the existing Identity
        identity = memberships.first.identity
        user.membership = identity.memberships.create!(user_id: user.id, user_tenant: user.tenant, email_address: user.email_address, account_name: Account.sole.name)
        puts "Merged membership for user #{user.id} (#{user.email_address}) into identity #{identity.id}"
      end
    end
  end
end
