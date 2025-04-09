require_relative "../../config/environment"

BUCKETS_COUNT = 100
BUBBLES_PER_BUCKET = 50

ApplicationRecord.current_tenant = "development-tenant"
account = Account.first
user = account.users.first
Current.session = user.sessions.last
workflow = account.workflows.first

BUCKETS_COUNT.times do |bucket_index|
  bucket = account.buckets.create!(name: "Collection #{bucket_index}", creator: user, workflow: workflow)
  BUBBLES_PER_BUCKET.times do |card_index|
    bucket.bubbles.create!(title: "Card #{card_index}", creator: user, status: :published)
  end
end
