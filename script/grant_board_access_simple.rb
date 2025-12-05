#!/usr/bin/env ruby
# Simple script to grant board access to an API token
#
# Usage:
#   docker-compose exec app bin/rails runner script/grant_board_access_simple.rb
#
# Modify the variables below according to your needs

# Configuration
TOKEN_STRING = "eaYCZNECreg9jrpTjQCEobWp"  # API token
BOARD_ID = nil                             # Board ID (nil = all boards)
BOARD_NAME = nil                            # Board name (alternative to BOARD_ID)

# Find the token
token = ApiToken.find_by(token: TOKEN_STRING)
unless token
  puts "Token not found: #{TOKEN_STRING}"
  exit 1
end

user = token.user
account = token.account

puts "Token: #{token.name}"
puts "User: #{user.name} (#{user.id})"
puts "Account: #{account.name}"

# Find boards
boards = if BOARD_ID
  [account.boards.find(BOARD_ID)]
elsif BOARD_NAME
  [account.boards.find_by!(name: BOARD_NAME)]
else
  account.boards.where(all_access: false)  # Only non-all_access boards
end

if boards.empty?
  puts "\nNo boards to process (or all boards are all_access)"
  exit 0
end

puts "\nBoards to process: #{boards.count}"
boards.each { |b| puts "  - #{b.name} (ID: #{b.id}, all_access: #{b.all_access?})" }

# Grant access
puts "\nGranting access..."
boards.each do |board|
  # Check if access already exists
  access = Access.find_by(user: user, board: board)
  
  if access
    puts "  → Access already exists for #{board.name}"
  else
    Access.create!(
      user: user,
      board: board,
      account: account,
      involvement: :access_only
    )
    puts "  ✓ Access granted to #{board.name}"
  end
end

puts "\nTotal accessible boards: #{user.boards.reload.count}"

