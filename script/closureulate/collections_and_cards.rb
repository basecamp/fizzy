require_relative "../../config/environment"

COLLECTIONS_COUNT = 100
CARDS_PER_COLLECTION = 50

ApplicationRecord.current_tenant = "development-tenant"
account = Account.first
user = account.users.first
Current.session = user.sessions.last
workflow = account.workflows.first

COLLECTIONS_COUNT.times do |collection_index|
  collection = account.collections.create!(name: "Collection #{collection_index}", creator: user, workflow: workflow)
  CARDS_PER_COLLECTION.times do |card_index|
    collection.cards.create!(title: "Card #{card_index}", creator: user, status: :published)
  end
end
