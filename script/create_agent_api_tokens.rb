#!/usr/bin/env ruby
# Script to create API tokens for Fizzy simulator agents
#
# Usage:
#   docker-compose exec app bin/rails runner script/create_agent_api_tokens.rb
#   OR
#   bin/rails runner script/create_agent_api_tokens.rb
#
# This script creates API tokens for each agent.
# Tokens are automatically associated with the account's system_user.

# Agent configurations - adjust these to match your simulator setup
AGENTS = [
  {
    email: "overcommitter@fizzy-sim.local",
    name: "The Overcommitter (Senior Developer)"
  },
  {
    email: "scope.creeper@fizzy-sim.local",
    name: "The Scope Creeper (Product Manager)"
  },
  {
    email: "perfectionist@fizzy-sim.local",
    name: "The Perfectionist (QA Engineer)"
  },
  {
    email: "ghost@fizzy-sim.local",
    name: "The Ghost (Contractor)"
  },
  {
    email: "bikeshedder@fizzy-sim.local",
    name: "The Bikeshedder (Tech Lead)"
  },
  {
    email: "arsonist@fizzy-sim.local",
    name: "The Arsonist (Junior Developer)"
  },
  {
    email: "lurker@fizzy-sim.local",
    name: "The Lurker (Stakeholder)"
  },
  {
    email: "automator@fizzy-sim.local",
    name: "The Automator (DevOps Engineer)"
  },
  {
    email: "archaeologist@fizzy-sim.local",
    name: "The Archaeologist (Staff Engineer)"
  },
  {
    email: "firefighter@fizzy-sim.local",
    name: "The Fire Fighter (On-Call Engineer)"
  }
].freeze

def create_api_token(account, name)
  # Use system_user (automatically set by ApiToken model callback)
  token = ApiToken.find_by(account: account, name: name)
  
  if token
    puts "  → API token already exists for #{name}"
    puts "     Token: #{token.token}"
    puts "     User: #{token.user.name}"
    return token
  end
  
  token = ApiToken.create!(
    account: account,
    name: name
  )
  
  puts "  ✓ Created API token for #{name}"
  puts "     Token: #{token.token}"
  puts "     User: #{token.user.name} (system_user)"
  
  token
end

# Main execution
puts "Creating API tokens for Fizzy simulator agents..."
puts "=" * 60

# Get or create the account (using the first account, or create a test one)
account = Account.first || Account.create!(name: "Test Account", external_account_id: 1)

puts "\nAccount: #{account.name} (ID: #{account.id})"
puts "\nProcessing agents:\n"

AGENTS.each do |agent|
  puts "\n#{agent[:name]} (#{agent[:email]}):"
  create_api_token(account, agent[:name])
end

puts "\n" + "=" * 60
puts "Done! Use these tokens in your FizzyApiClient configuration."
puts "\nExample usage in fizzy-hooligans:"
puts "  FizzyApiClient.new("
puts "    base_url: 'http://fizzy.localhost:3006',"
puts "    api_token: '<token_from_above>'"
puts "  )"

