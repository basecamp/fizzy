require_relative "../config/environment"
require "faker"

CARDS_COUNT = ARGV.first&.to_i || 10_000
COLLECTIONS_COUNT = ARGV.second&.to_i || 1

ApplicationRecord.current_tenant = ApplicationRecord.tenants.first
Current.session = Session.first

puts "Creating #{CARDS_COUNT} cards across #{COLLECTIONS_COUNT} collection(s)"

COLLECTIONS_COUNT.times do
  Collection.create! name: Faker::Company.buzzword, all_access: true
  print "."
end

CARDS_COUNT.times do
  card = Collection.take.cards.create! \
    title: Faker::Company.bs, description: Faker::Hacker.say_something_smart, status: :published

  print "."
end
