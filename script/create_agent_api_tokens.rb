#!/usr/bin/env ruby
# Script to create API tokens for Fizzy simulator agents
#
# Usage:
#   docker-compose exec app bin/rails runner script/create_agent_api_tokens.rb
#   OR
#   bin/rails runner script/create_agent_api_tokens.rb
#
# This script creates:
# - Users for each agent (if they don't exist)
# - API tokens for each agent

# Agent configurations - adjust these to match your simulator setup
AGENTS = [
  {
    email: "overcommitter@fizzy-sim.local",
    name: "Overcommitter Agent",
    role: "system"
  },
  {
    email: "perfectionist@fizzy-sim.local",
    name: "Perfectionist Agent",
    role: "system"
  },
  {
    email: "scope_creeper@fizzy-sim.local",
    name: "Scope Creeper Agent",
    role: "system"
  }
].freeze

def find_or_create_identity(email)
  Identity.find_or_create_by!(email_address: email)
end

def find_or_create_user(account, email, name, role)
  identity = find_or_create_identity(email)
  
  user = account.users.find_by(identity: identity)
  
  unless user
    user = account.users.create!(
      identity: identity,
      name: name,
      role: role
    )
    puts "  ✓ Created user: #{name} (#{email})"
  else
    puts "  → User already exists: #{name} (#{email})"
  end
  
  user
end

def create_api_token(account, user, name)
  token = ApiToken.find_by(account: account, user: user, name: name)
  
  if token
    puts "  → API token already exists for #{name}"
    puts "     Token: #{token.token}"
    return token
  end
  
  token = ApiToken.create!(
    account: account,
    user: user,
    name: name
  )
  
  puts "  ✓ Created API token for #{name}"
  puts "     Token: #{token.token}"
  
  token
end

# Main execution
puts "Creating API tokens for Fizzy simulator agents..."
puts "=" * 60

# Get or create the account (using the first account, or create a test one)
account = Account.first || Account.create!(name: "Test Account", external_account_id: 1)

puts "\nAccount: #{account.name} (ID: #{account.id})"
puts "\nProcessing agents:\n"

AGENTS.each do |agent_config|
  puts "\n#{agent_config[:name]}:"
  
  user = find_or_create_user(
    account,
    agent_config[:email],
    agent_config[:name],
    agent_config[:role]
  )
  
  create_api_token(account, user, agent_config[:name])
end

puts "\n" + "=" * 60
puts "Done! Use these tokens in your FizzyApiClient configuration."
puts "\nExample usage in fizzy-hooligans:"
puts "  FizzyApiClient.new("
puts "    base_url: 'http://fizzy.localhost:3006',"
puts "    api_token: '<token_from_above>'"
puts "  )"

