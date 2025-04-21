# Running `rails db:seed` will run `db:fixtures:load` in development.

ApplicationRecord.current_tenant = "development-tenant"

david = User.find_by_email_address("david@37signals.com")
jz = User.find_by_email_address("jz@37signals.com")
kevin = User.find_by_email_address("kevin@37signals.com")

Current.session = david.sessions.last

fizzy_collection = Collection.create! name: "Fizzy", creator: david
fizzy_collection.accesses.grant_to([ david, jz, kevin ])

fizzy_collection.cards.create!(title: "Prepare sign-up page", creator: david, status: :published).tap do |card|
  card.capture(Comment.new(body: "We need to do this before the launch."))
end

fizzy_collection.cards.create!(title: "Use streams to update the cards perma", creator: david, status: :published).tap do |card|
  card.capture(Comment.new(body: "Let's use streams everywhere!"))
  card.toggle_assignment(kevin)
  card.engage # Move to doing
end

fizzy_collection.cards.create!(title: "Plain text mentions", creator: david, status: :published).tap do |card|
  card.capture(Comment.new(body: "We'll support plain text mentions first."))
  card.toggle_assignment(david)
  card.close # Move to completed
end


