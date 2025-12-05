#!/usr/bin/env ruby
# Script to grant access to specific boards for all agent tokens
#
# Usage:
#   docker-compose exec app bin/rails runner script/grant_access_to_specific_boards.rb

# Configuration - modify these board IDs
BOARD_IDS = [
  "03f5se15dbufozspquhupbtjb",
  "03f5sejxe37ggf14dmoxatppj"
]

# Set to account ID where tokens are, or nil to auto-detect from boards
TOKEN_ACCOUNT_ID = nil

puts "Granting access to all agent tokens for specific boards..."
puts "=" * 60

# Find boards (they can be in any account)
boards = Board.where(id: BOARD_IDS)

if boards.empty?
  puts "\nERROR: No boards found with the specified IDs."
  exit
end

# Get the account from the boards (assuming all boards are in the same account)
board_account = boards.first.account
puts "\nBoards found:"
boards.each { |b| puts "  - #{b.name} (ID: #{b.id}) - Account: #{b.account.name}" }

# Get account for tokens - use board account to ensure tokens and boards are in same account
token_account = if TOKEN_ACCOUNT_ID
  Account.find(TOKEN_ACCOUNT_ID)
else
  board_account  # Use board account to ensure compatibility
end

puts "\nUsing account for tokens: #{token_account.name} (ID: #{token_account.id})"

# Get all active API tokens from the token account
tokens = ApiToken.where(account: token_account).active

# If no tokens exist, create them (using the same agent names as create_agent_api_tokens.rb)
if tokens.empty?
  puts "\nNo API tokens found. Creating agent tokens..."
  agent_names = [
    'The Overcommitter (Senior Developer)',
    'The Scope Creeper (Product Manager)',
    'The Perfectionist (QA Engineer)',
    'The Ghost (Contractor)',
    'The Bikeshedder (Tech Lead)',
    'The Arsonist (Junior Developer)',
    'The Lurker (Stakeholder)',
    'The Automator (DevOps Engineer)',
    'The Archaeologist (Staff Engineer)',
    'The Fire Fighter (On-Call Engineer)'
  ]
  
  agent_names.each do |name|
    token = ApiToken.find_or_create_by!(account: token_account, name: name)
    puts "  ✓ Created/found: #{name}"
  end
  
  tokens = ApiToken.where(account: token_account).active
end

puts "Tokens found: #{tokens.count}"
tokens.each { |t| puts "  - #{t.name}" }

puts "\nBoards to grant access to: #{boards.count}"
boards.each { |b| puts "  - #{b.name} (ID: #{b.id}, all_access: #{b.all_access?})" }

# Grant access
puts "\n" + "=" * 60
puts "Granting access..."
puts "=" * 60

boards.each do |board|
  puts "\nBoard: #{board.name} (Account: #{board.account.name})"
  
  tokens.each do |token|
    user = token.user
    # Check if user is in the same account as the board
    if user.account_id != board.account_id
      puts "  → #{token.name}: user is in different account, skipping"
      next
    end
    
    access = Access.find_by(user: user, board: board)
    
    if access
      puts "  → #{token.name}: access already exists"
    else
      Access.create!(
        user: user,
        board: board,
        account: board.account,
        involvement: :access_only
      )
      puts "  ✓ #{token.name}: access granted"
    end
  end
end

puts "\n" + "=" * 60
puts "Done!"
puts "\nVerification:"
tokens.each do |token|
  accessible_count = token.user.boards.reload.count
  puts "  #{token.name}: #{accessible_count} accessible board(s)"
end

