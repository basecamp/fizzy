require_relative "../../config/environment"

BUCKETS_COUNT = 100
BUBBLES_PER_COLLECTION = 50

ApplicationRecord.current_tenant = "development-tenant"
account = Account.first
user = account.users.first
Current.session = user.sessions.last
workflow = account.workflows.first

BUCKETS_COUNT.times do |collection_index|
  collection = account.collections.create!(name: "Collection #{collection_index}", creator: user, workflow: workflow)
  BUBBLES_PER_COLLECTION.times do |card_index|
    collection.cards.create!(title: "Card #{card_index}", creator: user, status: :published)
  end
end
