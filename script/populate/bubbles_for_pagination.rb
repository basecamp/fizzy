require_relative "../../config/environment"

BUBBLES_COUNT = 200

ApplicationRecord.current_tenant = "development-tenant"
account = Account.first
user = account.users.first
Current.session = user.sessions.last
bucket = account.buckets.first

# Doing

BUBBLES_COUNT.times do |index|
  bubble = bucket.bubbles.create!(title: "Doing card #{index}", creator: user, status: :published)
  bubble.engage
end

# Considering

BUBBLES_COUNT.times do |index|
  bubble = bucket.bubbles.create!(title: "Considering card #{index}", creator: user, status: :published)
  bubble.reconsider
end

# Completed

BUBBLES_COUNT.times do |index|
  bubble = bucket.bubbles.create!(title: "Popped card #{index}", creator: user, status: :published)
  bubble.pop!
end
