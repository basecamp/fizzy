#!/usr/bin/env ruby
# Script to grant board access to API tokens
#
# Usage:
#   docker-compose exec app bin/rails runner script/grant_board_access_to_api_tokens.rb
#   OR
#   bin/rails runner script/grant_board_access_to_api_tokens.rb
#
# This script grants access to boards for API tokens.
# You can specify:
#   - A specific token (by token string or name)
#   - A specific board (by ID or name)
#   - All boards in an account
#   - All tokens in an account

# Configuration - adjust these as needed
ACCOUNT_ID = nil  # Set to account ID or nil to use first account
TOKEN_NAME = nil  # Set to token name or nil for all tokens
BOARD_ID = nil    # Set to board ID or nil for all boards
BOARD_NAME = nil # Set to board name (alternative to BOARD_ID)

def grant_access_to_board(user, board, account)
  # Check if access already exists
  access = Access.find_by(user: user, board: board)
  
  if access
    puts "  → Access already exists for #{user.name} on #{board.name}"
    return access
  end
  
  # Create access
  access = Access.create!(
    user: user,
    board: board,
    account: account,
    involvement: :access_only
  )
  
  puts "  ✓ Access granted to #{user.name} on #{board.name}"
  access
end

def grant_access_to_boards_for_token(token, boards)
  user = token.user
  account = token.account
  
  puts "\nToken: #{token.name}"
  puts "  User: #{user.name} (#{user.id})"
  puts "  Account: #{account.name}"
  puts "  Boards to process: #{boards.count}"
  
  boards.each do |board|
    grant_access_to_board(user, board, account)
  end
  
  puts "  → Total accessible boards: #{user.boards.reload.count}"
end

# Main execution
puts "Granting board access to API tokens..."
puts "=" * 60

# Get account
account = if ACCOUNT_ID
  Account.find(ACCOUNT_ID)
else
  Account.first || (raise "No account found")
end

puts "\nAccount: #{account.name} (ID: #{account.id})"

# Get tokens
tokens = if TOKEN_NAME
  [ApiToken.find_by!(account: account, name: TOKEN_NAME)]
else
  ApiToken.where(account: account).active
end

if tokens.empty?
  puts "\nNo tokens found for this account."
  exit
end

puts "\nTokens found: #{tokens.count}"

# Get boards
boards = if BOARD_ID
  [account.boards.find(BOARD_ID)]
elsif BOARD_NAME
  [account.boards.find_by!(name: BOARD_NAME)]
else
  account.boards.all
end

if boards.empty?
  puts "\nNo boards found for this account."
  exit
end

puts "Boards found: #{boards.count}"
boards.each { |b| puts "  - #{b.name} (ID: #{b.id}, all_access: #{b.all_access?})" }

# Grant access
puts "\n" + "=" * 60
puts "Granting access..."
puts "=" * 60

tokens.each do |token|
  # For all_access boards, access is automatically granted to all active users
  # But we'll still create explicit access for API tokens to be safe
  boards_to_grant = boards.reject { |b| b.all_access? && b.account.users.active.include?(token.user) }
  
  if boards_to_grant.any?
    grant_access_to_boards_for_token(token, boards_to_grant)
  else
    puts "\nToken: #{token.name}"
    puts "  → All boards are all_access, automatic access"
  end
end

puts "\n" + "=" * 60
puts "Done!"

