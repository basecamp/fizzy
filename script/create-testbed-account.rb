#!/usr/bin/env ruby

require_relative "../config/environment"

raise "This script is for development only!" unless Rails.env.local?

user_name = "Ann"
email_address = "ann@example.com"
other_user_name = "Bob"
other_email_address = "bob@example.com"

# one tenant per zone
tenants = [ "Initech LLC", "Soylent Corp", "Globo Gym" ].each_with_object({}) do |name, hash|
  tenant = ActiveRecord::FixtureSet.identify(name)
  hash[tenant] = name
end

unless identity = Identity.find_by(email_address:)
  # assumes this script will be run on the default writer first to create these records
  puts "Creating identities and memberships ..."
  identity = Identity.create!(email_address:)
  tenants.keys.each { |tenant| identity.memberships.create!(tenant:) }

  Identity.create!(email_address: other_email_address).tap do |other_identity|
    tenants.keys.each { |tenant| other_identity.memberships.create!(tenant:) }
  end
end
other_identity = Identity.find_by!(email_address: other_email_address)

# find a tenant that doesn't exist yet
tenant = tenants.keys.find { |t| ! ApplicationRecord.tenant_exist?(t) }
company_name = tenants[tenant]

ApplicationRecord.create_tenant(tenant) do
  # set up account, first user, and customer template
  membership = identity.memberships.find_by!(tenant:)

  account = Account.create_with_admin_user(
    account: { external_account_id: tenant, name: company_name },
    owner: { name: user_name,  membership: }
  )

  Current.membership = membership
  account.setup_customer_template

  # set up second user
  other_membership = other_identity.memberships.find_by!(tenant:)
  User.create! name: other_user_name, membership: other_membership, role: "member"
end

puts "Created account for #{company_name} (#{tenant}) on #{`hostname`.chomp}."
