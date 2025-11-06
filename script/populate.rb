require_relative "../config/environment"
require "faker"

CARDS_COUNT = ARGV.first&.to_i || 10_000
BOARDS_COUNT = ARGV.second&.to_i || 1

ApplicationRecord.current_tenant = ApplicationRecord.tenants.first
Current.session = Session.first

puts "Creating #{CARDS_COUNT} cards across #{BOARDS_COUNT} board(s)"

BOARDS_COUNT.times do
  Board.create! name: Faker::Company.buzzword, all_access: true
  print "."
end

CARDS_COUNT.times do
  card = Board.take.cards.create! \
    title: Faker::Company.bs, description: Faker::Hacker.say_something_smart, status: :published

  print "."
end
